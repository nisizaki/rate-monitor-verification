theory Concurrent_Bot
  imports Bot_Rate
begin

datatype concurrent_event = Time nat | Local nat action

fun project :: "concurrent_event \<Rightarrow> event" where
  "project (Time d) = Tick d"
| "project (Local i SendRequest) = Send"
| "project (Local i a) = Other"

inductive concurrent_step :: "nat \<Rightarrow> nat \<Rightarrow> ((nat \<Rightarrow> phase) \<times> nat) \<Rightarrow> concurrent_event \<Rightarrow> ((nat \<Rightarrow> phase) \<times> nat) \<Rightarrow> bool" where
  time: "step B r b (Tick d) b' \<Longrightarrow> concurrent_step B r (ps,b) (Time d) (ps,b')"
| local: "bot_step (ps i) a p' \<Longrightarrow> step B r b (project (Local i a)) b' \<Longrightarrow> concurrent_step B r (ps,b) (Local i a) (ps(i := p'),b')"

inductive concurrent_run :: "nat \<Rightarrow> nat \<Rightarrow> ((nat \<Rightarrow> phase) \<times> nat) \<Rightarrow> concurrent_event list \<Rightarrow> ((nat \<Rightarrow> phase) \<times> nat) \<Rightarrow> bool" where
  nil: "concurrent_run B r s [] s"
| cons: "concurrent_step B r s e s' \<Longrightarrow> concurrent_run B r s' es s'' \<Longrightarrow> concurrent_run B r s (e # es) s''"

lemma concurrent_step_projection:
  assumes "concurrent_step B r s e s'"
  shows "step B r (snd s) (project e) (snd s')"
  using assms by (cases rule: concurrent_step.cases) auto

lemma concurrent_run_projection:
  assumes "concurrent_run B r s es s'"
  shows "run B r (snd s) (map project es) (snd s')"
  using assms
  by (induction rule: concurrent_run.induct) (auto intro: run.intros dest: concurrent_step_projection)

fun is_request :: "concurrent_event \<Rightarrow> bool" where
  "is_request (Local i SendRequest) = True"
| "is_request e = False"

lemma requests_projection:
  "sends (map project es) = length (filter is_request es)"
proof (induction es)
  case Nil then show ?case by simp
next
  case (Cons e es)
  show ?case
  proof (cases e)
    case (Time d) then show ?thesis using Cons.IH by simp
  next
    case (Local i a) then show ?thesis using Cons.IH by (cases a) auto
  qed
qed

theorem shared_rate_bound:
  assumes "concurrent_run B r (ps,b) es (ps',b')" "b \<le> B"
  shows "length (filter is_request es) \<le> B + r * elapsed (map project es)"
proof -
  have R: "run B r b (map project es) b'"
    using concurrent_run_projection[OF assms(1)] by simp
  from rate_bound[OF R assms(2)] show ?thesis
    using requests_projection[of es] by simp
qed

lemma shared_two_sends:
  assumes "B > 1"
  shows "\<exists>s. concurrent_run B r ((\<lambda>_. Ready),B) [Local 0 SendRequest, Local 1 SendRequest] s"
proof -
  let ?ps = "\<lambda>_. Ready"
  let ?ps1 = "?ps(0 := InFlight)"
  have P: "0 < B - 1" using assms by arith
  have Q: "0 < B" using assms by arith
  have CS: "step B r (B - 1) Send ((B - 1) - 1)"
    using P by (rule step.send)
  have A: "concurrent_step B r (?ps,B) (Local 0 SendRequest) (?ps1,B - 1)"
    using Q apply (auto intro!: concurrent_step.local bot_step.send step.send)
    by (metis One_nat_def step.send)
  have C: "concurrent_step B r (?ps1,B - 1) (Local 1 SendRequest) (?ps1(1 := InFlight),(B - 1) - 1)"
    using CS by (auto intro!: concurrent_step.local bot_step.send)
  have "concurrent_run B r (?ps,B) [Local 0 SendRequest, Local 1 SendRequest] (?ps1(1 := InFlight),(B - 1) - 1)"
    using A C by (meson concurrent_run.cons concurrent_run.nil)
  then show ?thesis by blast
qed

inductive independent_step :: "nat \<Rightarrow> nat \<Rightarrow> ((nat \<Rightarrow> phase) \<times> (nat \<Rightarrow> nat)) \<Rightarrow> concurrent_event \<Rightarrow> ((nat \<Rightarrow> phase) \<times> (nat \<Rightarrow> nat)) \<Rightarrow> bool" where
  local: "bot_step (ps i) a p' \<Longrightarrow> step B r (bs i) (project (Local i a)) b' \<Longrightarrow> independent_step B r (ps,bs) (Local i a) (ps(i := p'),bs(i := b'))"

inductive independent_run :: "nat \<Rightarrow> nat \<Rightarrow> ((nat \<Rightarrow> phase) \<times> (nat \<Rightarrow> nat)) \<Rightarrow> concurrent_event list \<Rightarrow> ((nat \<Rightarrow> phase) \<times> (nat \<Rightarrow> nat)) \<Rightarrow> bool" where
  nil: "independent_run B r s [] s"
| cons: "independent_step B r s e s' \<Longrightarrow> independent_run B r s' es s'' \<Longrightarrow> independent_run B r s (e # es) s''"

lemma independent_two_sends:
  assumes "B > 0"
  shows "\<exists>s. independent_run B r ((\<lambda>_. Ready),(\<lambda>_. B)) [Local 0 SendRequest, Local 1 SendRequest] s"
proof -
  let ?ps = "\<lambda>_. Ready"
  let ?bs = "\<lambda>_. B"
  let ?ps1 = "?ps(0 := InFlight)"
  let ?bs1 = "?bs(0 := B - 1)"
  have A: "independent_step B r (?ps,?bs) (Local 0 SendRequest) (?ps1,?bs1)"
    using assms apply (auto intro!: independent_step.local bot_step.send step.send)
    by (metis One_nat_def step.send)
  have C: "independent_step B r (?ps1,?bs1) (Local 1 SendRequest) (?ps1(1 := InFlight),?bs1(1 := B - 1))"
    using assms apply (auto intro!: independent_step.local bot_step.send step.send)
    by (metis One_nat_def step.send)
  have "independent_run B r (?ps,?bs) [Local 0 SendRequest, Local 1 SendRequest] (?ps1(1 := InFlight),?bs1(1 := B - 1))"
    using A C by (meson independent_run.cons independent_run.nil)
  then show ?thesis by blast
qed

theorem independent_buckets_counterexample:
  "\<exists>s. independent_run 1 0 ((\<lambda>_. Ready),(\<lambda>_. 1)) [Local 0 SendRequest, Local 1 SendRequest] s \<and>
       length (filter is_request [Local 0 SendRequest, Local 1 SendRequest]) > 1 + 0 * elapsed (map project [Local 0 SendRequest, Local 1 SendRequest])"
  using independent_two_sends[of 1 0] by simp

end
