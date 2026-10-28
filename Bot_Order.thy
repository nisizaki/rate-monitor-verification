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

end
