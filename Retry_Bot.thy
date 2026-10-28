theory Retry_Bot
  imports Rate_Bucket
begin

datatype status = Waiting | Active | Finished
record job =
  status :: status
  attempts :: nat
  retry_at :: nat
  deadline :: nat

record system_state =
  now :: nat
  tokens :: nat
  jobs :: "nat \<Rightarrow> job"

datatype retry_event = Advance nat | Dispatch nat | RateLimited nat nat nat | QuotaExceeded nat | TimedOut nat | Success nat | Expire nat

fun bucket_of :: "retry_event \<Rightarrow> event" where
  "bucket_of (Advance d) = Tick d"
| "bucket_of (Dispatch i) = Send"
| "bucket_of e = Other"

inductive retry_step :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> system_state \<Rightarrow> retry_event \<Rightarrow> system_state \<Rightarrow> bool" where
  advance: "retry_step B r K s (Advance d) (s\<lparr>now := now s + d, tokens := min B (tokens s + r*d)\<rparr>)"
| dispatch: "\<lbrakk>status (jobs s i) = Waiting; attempts (jobs s i) < K; retry_at (jobs s i) \<le> now s; now s < deadline (jobs s i); tokens s > 0\<rbrakk> \<Longrightarrow> retry_step B r K s (Dispatch i) (s\<lparr>tokens := tokens s - 1, jobs := (jobs s)(i := (jobs s i)\<lparr>status := Active, attempts := Suc (attempts (jobs s i))\<rparr>)\<rparr>)"
| limited: "\<lbrakk>status (jobs s i) = Active; attempts (jobs s i) < K\<rbrakk> \<Longrightarrow> retry_step B r K s (RateLimited i backoff hint) (s\<lparr>jobs := (jobs s)(i := (jobs s i)\<lparr>status := Waiting, retry_at := now s + max backoff hint\<rparr>)\<rparr>)"
| exhausted: "\<lbrakk>status (jobs s i) = Active; attempts (jobs s i) \<ge> K\<rbrakk> \<Longrightarrow> retry_step B r K s (RateLimited i backoff hint) (s\<lparr>jobs := (jobs s)(i := (jobs s i)\<lparr>status := Finished\<rparr>)\<rparr>)"
| quota: "status (jobs s i) = Active \<Longrightarrow> retry_step B r K s (QuotaExceeded i) (s\<lparr>jobs := (jobs s)(i := (jobs s i)\<lparr>status := Finished\<rparr>)\<rparr>)"
| timeout: "status (jobs s i) = Active \<Longrightarrow> retry_step B r K s (TimedOut i) (s\<lparr>jobs := (jobs s)(i := (jobs s i)\<lparr>status := Finished\<rparr>)\<rparr>)"
| success: "status (jobs s i) = Active \<Longrightarrow> retry_step B r K s (Success i) (s\<lparr>jobs := (jobs s)(i := (jobs s i)\<lparr>status := Finished\<rparr>)\<rparr>)"
| expire: "\<lbrakk>status (jobs s i) = Waiting; deadline (jobs s i) \<le> now s\<rbrakk> \<Longrightarrow> retry_step B r K s (Expire i) (s\<lparr>jobs := (jobs s)(i := (jobs s i)\<lparr>status := Finished\<rparr>)\<rparr>)"

inductive retry_run :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> system_state \<Rightarrow> retry_event list \<Rightarrow> system_state \<Rightarrow> bool" where
  nil: "retry_run B r K s [] s"
| cons: "retry_step B r K s e s' \<Longrightarrow> retry_run B r K s' es s'' \<Longrightarrow> retry_run B r K s (e # es) s''"

lemma dispatch_guards:
  assumes "retry_step B r K s (Dispatch i) s'"
  shows "status (jobs s i) = Waiting \<and> attempts (jobs s i) < K \<and> retry_at (jobs s i) \<le> now s \<and> now s < deadline (jobs s i) \<and> tokens s > 0"
  using assms by (cases rule: retry_step.cases) auto

lemma retry_step_projection:
  assumes "retry_step B r K s e s'"
  shows "step B r (tokens s) (bucket_of e) (tokens s')"
  using assms apply (cases rule: retry_step.cases)
  apply (auto intro: step.intros)
  by (metis One_nat_def step.send)

lemma retry_run_projection:
  assumes "retry_run B r K s es s'"
  shows "run B r (tokens s) (map bucket_of es) (tokens s')"
  using assms by (induction rule: retry_run.induct) (auto intro: run.intros dest: retry_step_projection)

theorem retry_rate_bound:
  assumes "retry_run B r K s es s'" "tokens s \<le> B"
  shows "sends (map bucket_of es) \<le> B + r * elapsed (map bucket_of es)"
  using rate_bound[OF retry_run_projection[OF assms(1)] assms(2)] .

definition bounded :: "nat \<Rightarrow> system_state \<Rightarrow> bool" where
  "bounded K s \<longleftrightarrow> (\<forall>i. attempts (jobs s i) \<le> K)"

lemma bounded_step:
  assumes "retry_step B r K s e s'" "bounded K s"
  shows "bounded K s'"
  using assms by (cases rule: retry_step.cases) (auto simp: bounded_def)

theorem bounded_run:
  assumes "retry_run B r K s es s'" "bounded K s"
  shows "bounded K s'"
  using assms by (induction rule: retry_run.induct) (auto dest: bounded_step)

lemma attempts_step:
  assumes "retry_step B r K s e s'"
  shows "attempts (jobs s' i) = attempts (jobs s i) + (if e = Dispatch i then 1 else 0)"
  using assms by (cases rule: retry_step.cases) auto

fun dispatches :: "nat \<Rightarrow> retry_event list \<Rightarrow> nat" where
  "dispatches i [] = 0"
| "dispatches i (e # es) = (if e = Dispatch i then 1 else 0) + dispatches i es"

theorem attempts_account:
  assumes "retry_run B r K s es s'"
  shows "attempts (jobs s' i) = attempts (jobs s i) + dispatches i es"
  using assms
proof (induction rule: retry_run.induct)
  case (nil B r K s)
  then show ?case by simp
next
  case (cons B r K s e s' es s'')
  from attempts_step[OF cons.hyps(1), of i] cons.IH show ?case by simp
qed

theorem attempts_limit:
  assumes "retry_run B r K s es s'" "bounded K s" "attempts (jobs s i) = 0"
  shows "dispatches i es \<le> K"
proof -
  have A: "attempts (jobs s' i) \<le> K"
    using bounded_run[OF assms(1,2)] unfolding bounded_def by blast
  have E: "attempts (jobs s' i) = dispatches i es"
    using attempts_account[OF assms(1), of i] assms(3) by simp
  from A E show ?thesis by simp
qed

lemma finished_step:
  assumes "retry_step B r K s e s'" "status (jobs s i) = Finished"
  shows "status (jobs s' i) = Finished"
  using assms by (cases rule: retry_step.cases) auto

theorem finished_run:
  assumes "retry_run B r K s es s'" "status (jobs s i) = Finished"
  shows "status (jobs s' i) = Finished"
  using assms by (induction rule: retry_run.induct) (auto dest: finished_step)

theorem finished_no_dispatch:
  assumes "retry_run B r K s es s'" "status (jobs s i) = Finished"
  shows "dispatches i es = 0"
  using assms
  by (induction rule: retry_run.induct) (auto dest: finished_step dispatch_guards)

lemma limited_wait:
  assumes "retry_step B r K s (RateLimited i backoff hint) s'" "status (jobs s' i) = Waiting"
  shows "retry_at (jobs s' i) = now s + max backoff hint \<and> now s' = now s"
  using assms by (cases rule: retry_step.cases) auto

lemma quota_finishes:
  assumes "retry_step B r K s (QuotaExceeded i) s'"
  shows "status (jobs s' i) = Finished"
  using assms by (cases rule: retry_step.cases) auto

lemma timeout_finishes:
  assumes "retry_step B r K s (TimedOut i) s'"
  shows "status (jobs s' i) = Finished"
  using assms by (cases rule: retry_step.cases) auto

end
