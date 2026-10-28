theory Permit_Bridge
  imports Concurrent_Bot Permit_Operational
begin

inductive_cases concurrent_run_consE: "concurrent_run B r s (e # es) s'"

lemma concurrent_run_cons_iff:
  "concurrent_run B r s (e # es) t \<longleftrightarrow> (\<exists>m. concurrent_step B r s e m \<and> concurrent_run B r m es t)"
  by (metis concurrent_run.cons concurrent_run_consE)

lemma concurrent_run_nil_iff:
  "concurrent_run B r s [] t \<longleftrightarrow> s = t"
  by (metis concurrent_run.nil concurrent_run.cases list.distinct(1))

lemma concurrent_run_append:
  "concurrent_run B r s (xs @ ys) t \<longleftrightarrow> (\<exists>m. concurrent_run B r s xs m \<and> concurrent_run B r m ys t)"
  by (induction xs arbitrary: s t) (auto simp: concurrent_run_cons_iff concurrent_run_nil_iff)

lemma concurrent_middle_bound:
  assumes R: "concurrent_run B r s (prefix @ middle @ suffix) t"
      and initial: "snd s \<le> B"
  shows "length (filter is_request middle) \<le> B + r * elapsed (map project middle)"
proof -
  from R obtain x y where P: "concurrent_run B r s prefix x" and M: "concurrent_run B r x middle y"
    using concurrent_run_append by blast
  have "run B r (snd s) (map project prefix) (snd x)"
    using concurrent_run_projection[OF P] .
  then have X: "snd x \<le> B" using initial run_bound by blast
  have "sends (map project middle) \<le> B + r * elapsed (map project middle)"
    using rate_bound[OF concurrent_run_projection[OF M] X] .
  then show ?thesis using requests_projection by simp
qed

definition window_correspondence :: "'a set \<Rightarrow> ('a \<Rightarrow> nat) \<Rightarrow> concurrent_event list \<Rightarrow> bool" where
  "window_correspondence ids grant es \<longleftrightarrow>
   (\<forall>s t. s \<le> t \<longrightarrow> (\<exists>prefix middle suffix.
       es = prefix @ middle @ suffix \<and>
       card (interval_ids ids grant s t) = length (filter is_request middle) \<and>
       elapsed (map project middle) \<le> t - s))"

theorem run_gives_grant_bound:
  assumes R: "concurrent_run B r initial es final" and I: "snd initial \<le> B"
      and W: "window_correspondence ids grant es"
  shows "rate_constrained ids grant B r"
proof (unfold rate_constrained_def, intro allI impI)
  fix s t :: nat
  assume ST: "s \<le> t"
  from W ST obtain prefix middle suffix where E: "es = prefix @ middle @ suffix"
    and C: "card (interval_ids ids grant s t) = length (filter is_request middle)"
    and D: "elapsed (map project middle) \<le> t - s"
    unfolding window_correspondence_def by blast
  have R': "concurrent_run B r initial (prefix @ middle @ suffix) final" using R E by simp
  have "length (filter is_request middle) \<le> B + r * elapsed (map project middle)"
    using concurrent_middle_bound[OF R' I] .
  moreover have "B + r * elapsed (map project middle) \<le> B + r * (t - s)"
    using D by (simp add: mult_le_mono)
  ultimately show "card (interval_ids ids grant s t) \<le> B + r * (t - s)" using C by arith
qed

theorem run_to_fetch_bound:
  assumes "concurrent_run B r initial es final" "snd initial \<le> B"
    "window_correspondence grants grant es" "finite grants" "fetches \<subseteq> grants"
    "\<And>i. i \<in> fetches \<Longrightarrow> grant i \<le> fetch i \<and> fetch i \<le> grant i + D"
    "s \<le> t"
  shows "card (interval_ids fetches fetch s t) \<le> B + r * ((t - s) + D)"
proof -
  have G: "rate_constrained grants grant B r" using run_gives_grant_bound[OF assms(1-3)] .
  show ?thesis using fetch_bound_with_delay[OF assms(4,5,6) G assms(7)] .
qed

theorem concurrent_operational_fetch_bound:
  assumes C: "concurrent_run B r c0 ces c1" "snd c0 \<le> B"
    and P: "permit_run B r D p0 pes p1" "permit_valid D p0"
    and W: "window_correspondence (issued p1) (granted_at p1) ces"
    and AB: "a \<le> b"
  shows "card (interval_ids (fetched p1) (fetched_at p1) a b) \<le> B + r * ((b - a) + D)"
proof -
  have G: "rate_constrained (issued p1) (granted_at p1) B r"
    using run_gives_grant_bound[OF C W] .
  show ?thesis using operational_fetch_bound[OF P G AB] .
qed

end
