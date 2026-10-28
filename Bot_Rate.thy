theory Bot_Rate
  imports Bot_Order Rate_Bucket
begin

datatype bot_event = Clock nat | Action action

fun bucket_event :: "bot_event \<Rightarrow> event" where
  "bucket_event (Clock d) = Tick d"
| "bucket_event (Action SendRequest) = Send"
| "bucket_event (Action a) = Other"

inductive paired_step :: "nat \<Rightarrow> nat \<Rightarrow> (phase \<times> nat) \<Rightarrow> bot_event \<Rightarrow> (phase \<times> nat) \<Rightarrow> bool" where
  clock: "step B r b (Tick d) b' \<Longrightarrow> paired_step B r (p,b) (Clock d) (p,b')"
| action: "bot_step p a p' \<Longrightarrow> step B r b (bucket_event (Action a)) b' \<Longrightarrow> paired_step B r (p,b) (Action a) (p',b')"

inductive paired_run :: "nat \<Rightarrow> nat \<Rightarrow> (phase \<times> nat) \<Rightarrow> bot_event list \<Rightarrow> (phase \<times> nat) \<Rightarrow> bool" where
  nil: "paired_run B r s [] s"
| cons: "paired_step B r s e s' \<Longrightarrow> paired_run B r s' es s'' \<Longrightarrow> paired_run B r s (e # es) s''"

lemma paired_step_bucket:
  assumes "paired_step B r (p,b) e (p',b')"
  shows "step B r b (bucket_event e) b'"
  using assms by (cases rule: paired_step.cases) auto

lemma paired_run_bucket:
  assumes "paired_run B r s es s'"
  shows "run B r (snd s) (map bucket_event es) (snd s')"
  using assms
proof (induction rule: paired_run.induct)
  case (nil B r s)
  then show ?case by (simp add: run.nil)
next
  case (cons B r s e s' es s'')
  have "step B r (snd s) (bucket_event e) (snd s')"
    using cons.hyps(1) by (cases s; cases s') (auto dest: paired_step_bucket)
  then show ?case using cons.IH by (auto intro: run.cons)
qed

lemma send_count_correspondence:
  "sends (map bucket_event es) = length (filter (\<lambda>e. e = Action SendRequest) es)"
proof (induction es)
  case Nil
  then show ?case by simp
next
  case (Cons e es)
  show ?case
  proof (cases e)
    case (Clock d)
    then show ?thesis using Cons.IH by simp
  next
    case (Action a)
    then show ?thesis using Cons.IH by (cases a) auto
  qed
qed

theorem bot_send_rate_bound:
  assumes "paired_run B r (p,b) es (p',b')" "b \<le> B"
  shows "sends (map bucket_event es) \<le> B + r * elapsed (map bucket_event es)"
  using paired_run_bucket[OF assms(1)] assms(2) rate_bound by auto

corollary request_rate_bound:
  assumes "paired_run B r (p,b) es (p',b')" "b \<le> B"
  shows "length (filter (\<lambda>e. e = Action SendRequest) es) \<le> B + r * elapsed (map bucket_event es)"
  using bot_send_rate_bound[OF assms] send_count_correspondence by metis

end
