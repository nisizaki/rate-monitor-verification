theory Rate_Monitor
  imports Rate_Bucket
begin

fun monitor_step :: "nat \<Rightarrow> nat \<Rightarrow> nat option \<Rightarrow> event \<Rightarrow> nat option" where
  "monitor_step B r None e = None"
| "monitor_step B r (Some b) (Tick d) = Some (min B (b + r * d))"
| "monitor_step B r (Some b) Send = (if b > 0 then Some (b - 1) else None)"
| "monitor_step B r (Some b) Other = Some b"

fun monitor :: "nat \<Rightarrow> nat \<Rightarrow> nat option \<Rightarrow> event list \<Rightarrow> nat option" where
  "monitor B r s [] = s"
| "monitor B r s (e # es) = monitor B r (monitor_step B r s e) es"

lemma monitor_none [simp]: "monitor B r None es = None"
  by (induction es) (auto split: event.splits)

lemma step_monitor:
  "step B r b e b' \<longleftrightarrow> monitor_step B r (Some b) e = Some b'"
  apply (cases e)
  apply (auto intro: step.intros elim: step.cases)
  apply (metis One_nat_def step.send)
  done

theorem run_monitor:
  "run B r b es b' \<longleftrightarrow> monitor B r (Some b) es = Some b'"
proof (induction es arbitrary: b)
  case Nil
  then show ?case by (auto intro: run.nil elim: run.cases)
next
  case (Cons e es)
  show ?case
  proof
    assume R: "run B r b (e # es) b'"
    then obtain c where A: "step B r b e c" and C: "run B r c es b'"
      by (cases rule: run.cases) auto
    from A have "monitor_step B r (Some b) e = Some c" using step_monitor by blast
    moreover from C Cons.IH have "monitor B r (Some c) es = Some b'" by blast
    ultimately show "monitor B r (Some b) (e # es) = Some b'" by simp
  next
    assume M: "monitor B r (Some b) (e # es) = Some b'"
    then obtain c where A: "monitor_step B r (Some b) e = Some c"
      by (cases "monitor_step B r (Some b) e") auto
    from M A have C: "monitor B r (Some c) es = Some b'" by simp
    have "step B r b e c" using A step_monitor by blast
    moreover have "run B r c es b'" using C Cons.IH by blast
    ultimately show "run B r b (e # es) b'" by (rule run.cons)
  qed
qed

theorem accepted_rate_bound:
  assumes "monitor B r (Some b) es = Some b'" "b \<le> B"
  shows "sends es \<le> B + r * elapsed es"
  using rate_bound[of B r b es b'] assms run_monitor by blast

end
