theory Rate_Bucket
  imports Main
begin

datatype event = Tick nat | Send | Other

inductive step :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event \<Rightarrow> nat \<Rightarrow> bool" where
  tick: "step B r b (Tick d) (min B (b + r * d))"
| send: "b > 0 \<Longrightarrow> step B r b Send (b - 1)"
| other: "step B r b Other b"

inductive run :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event list \<Rightarrow> nat \<Rightarrow> bool" where
  nil: "run B r b [] b"
| cons: "step B r b e b' \<Longrightarrow> run B r b' es b'' \<Longrightarrow> run B r b (e # es) b''"

fun sends :: "event list \<Rightarrow> nat" where
  "sends [] = 0"
| "sends (Send # es) = Suc (sends es)"
| "sends (Tick d # es) = sends es"
| "sends (Other # es) = sends es"

fun elapsed :: "event list \<Rightarrow> nat" where
  "elapsed [] = 0"
| "elapsed (Tick d # es) = d + elapsed es"
| "elapsed (Send # es) = elapsed es"
| "elapsed (Other # es) = elapsed es"

lemma step_bound:
  assumes "step B r b e b'" "b \<le> B"
  shows "b' \<le> B"
  using assms by (cases rule: step.cases) auto

theorem run_bound:
  assumes "run B r b es b'" "b \<le> B"
  shows "b' \<le> B"
  using assms by (induction rule: run.induct) (auto dest: step_bound)

lemma step_account:
  assumes "step B r b e b'"
  shows "sends [e] + b' \<le> b + r * elapsed [e]"
  using assms by (cases rule: step.cases) (auto simp: algebra_simps)

theorem run_account:
  assumes "run B r b es b'"
  shows "sends es + b' \<le> b + r * elapsed es"
  using assms
proof (induction rule: run.induct)
  case (nil B r b)
  then show ?case by simp
next
  case (cons B r b e b' es b'')
  have A: "sends [e] + b' \<le> b + r * elapsed [e]"
    using step_account[OF cons.hyps(1)] .
  have S: "sends (e # es) = sends [e] + sends es"
    by (cases e) auto
  have T: "elapsed (e # es) = elapsed [e] + elapsed es"
    by (cases e) auto
  show ?case using A cons.IH unfolding S T by (simp add: algebra_simps; arith)
qed

theorem rate_bound:
  assumes "run B r b es b'" "b \<le> B"
  shows "sends es \<le> B + r * elapsed es"
  using run_account[OF assms(1)] assms(2) by arith

end
