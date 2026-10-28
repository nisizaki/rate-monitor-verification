theory Instrumented_Retry
  imports Retry_Bot Rate_Monitor
begin

inductive observed_run ::
  "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> system_state \<Rightarrow> nat option \<Rightarrow> retry_event list \<Rightarrow> system_state \<Rightarrow> nat option \<Rightarrow> bool" where
  nil: "observed_run B r K s m [] s m"
| cons: "\<lbrakk>retry_step B r K s e s'; observed_run B r K s' (monitor_step B r m (bucket_of e)) es s'' m'\<rbrakk> \<Longrightarrow>
    observed_run B r K s m (e # es) s'' m'"

theorem erase_observer:
  assumes "observed_run B r K s m es s' m'"
  shows "retry_run B r K s es s'"
  using assms by (induction rule: observed_run.induct) (auto intro: retry_run.intros)

theorem observer_result:
  assumes "observed_run B r K s m es s' m'"
  shows "m' = monitor B r m (map bucket_of es)"
  using assms by (induction rule: observed_run.induct) auto

theorem attach_observer:
  assumes "retry_run B r K s es s'"
  shows "observed_run B r K s m es s' (monitor B r m (map bucket_of es))"
  using assms
  by (induction arbitrary: m rule: retry_run.induct) (auto intro: observed_run.intros)

theorem observational_correspondence:
  "observed_run B r K s m es s' m' \<longleftrightarrow>
    retry_run B r K s es s' \<and> m' = monitor B r m (map bucket_of es)"
  by (metis erase_observer observer_result attach_observer)

corollary rejected_monitor_does_not_block:
  assumes "retry_run B r K s es s'"
  shows "observed_run B r K s None es s' None"
  using attach_observer[OF assms, of None] by simp

theorem monitor_trace_correct:
  "monitor B r (Some b) (map bucket_of es) = Some b' \<longleftrightarrow>
    run B r b (map bucket_of es) b'"
  using run_monitor by metis

theorem monitor_matches_bucket:
  assumes "observed_run B r K s (Some (tokens s)) es s' m'"
  shows "m' = Some (tokens s')"
proof -
  have R: "retry_run B r K s es s'" using erase_observer[OF assms] .
  have "run B r (tokens s) (map bucket_of es) (tokens s')"
    using retry_run_projection[OF R] .
  then have "monitor B r (Some (tokens s)) (map bucket_of es) = Some (tokens s')"
    using run_monitor by blast
  then show ?thesis using observer_result[OF assms] by simp
qed

theorem monitored_rate_bound:
  assumes "observed_run B r K s m es s' (Some b')" "m = Some b" "b \<le> B"
  shows "sends (map bucket_of es) \<le> B + r * elapsed (map bucket_of es)"
proof -
  have M: "monitor B r (Some b) (map bucket_of es) = Some b'"
    using observer_result[OF assms(1)] assms(2) by simp
  show ?thesis using accepted_rate_bound[OF M assms(3)] .
qed

end
