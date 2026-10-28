theory Bot_Order
  imports Main
begin

datatype phase = Prepare | Ready | InFlight | Decode | Post | Audit | Mark | Done
datatype action = PrepareOK | SendRequest | HttpOK | ValidTranslation | ReplyOK | AuditDone | MarkOK | Fail

inductive bot_step :: "phase \<Rightarrow> action \<Rightarrow> phase \<Rightarrow> bool" where
  prepare: "bot_step Prepare PrepareOK Ready"
| send: "bot_step Ready SendRequest InFlight"
| http: "bot_step InFlight HttpOK Decode"
| valid: "bot_step Decode ValidTranslation Post"
| reply: "bot_step Post ReplyOK Audit"
| audit: "bot_step Audit AuditDone Mark"
| mark: "bot_step Mark MarkOK Done"
| fail: "bot_step p Fail Done"

inductive bot_run :: "phase \<Rightarrow> action list \<Rightarrow> phase \<Rightarrow> bool" where
  nil: "bot_run p [] p"
| cons: "bot_step p a q \<Longrightarrow> bot_run q as r \<Longrightarrow> bot_run p (a # as) r"

lemma mark_requires_reply:
  assumes "bot_run p as q" "q = Mark \<or> MarkOK \<in> set as"
  shows "p = Mark \<or> p = Audit \<or> ReplyOK \<in> set as"
  using assms
  by (induction rule: bot_run.induct) (auto elim: bot_step.cases)

theorem completion_requires_reply:
  assumes "bot_run Prepare as q" "MarkOK \<in> set as"
  shows "ReplyOK \<in> set as"
  using mark_requires_reply[OF assms(1)] assms(2) by auto

inductive_cases bot_run_consE: "bot_run p (a # xs) q"

lemma bot_run_cons_iff:
  "bot_run p (a # xs) q \<longleftrightarrow> (\<exists>m. bot_step p a m \<and> bot_run m xs q)"
  by (metis bot_run.cons bot_run_consE)

lemma bot_run_nil_iff: "bot_run p [] q \<longleftrightarrow> p = q"
  by (metis bot_run.nil bot_run.cases list.distinct(1))

lemma bot_run_append:
  "bot_run p (xs @ ys) q \<longleftrightarrow> (\<exists>m. bot_run p xs m \<and> bot_run m ys q)"
  by (induction xs arbitrary: p q) (auto simp: bot_run_cons_iff bot_run_nil_iff)

theorem completion_after_reply:
  assumes R: "bot_run Prepare as q" and M: "MarkOK \<in> set as"
  shows "\<exists>xs ys zs. as = xs @ [ReplyOK] @ ys @ [MarkOK] @ zs"
proof -
  obtain pre post where E: "as = pre @ MarkOK # post"
    using M by (metis split_list)
  from R E obtain m where P: "bot_run Prepare pre m" and Q: "bot_run m (MarkOK # post) q"
    using bot_run_append by blast
  from Q have "m = Mark" by (auto elim: bot_run.cases bot_step.cases)
  with P have "ReplyOK \<in> set pre" using mark_requires_reply by blast
  then obtain xs ys where "pre = xs @ ReplyOK # ys" by (metis split_list)
  with E show ?thesis by auto
qed

end
