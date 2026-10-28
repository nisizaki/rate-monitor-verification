theory Permit_Delay
  imports Main
begin

definition interval_ids :: "'a set \<Rightarrow> ('a \<Rightarrow> nat) \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> 'a set" where
  "interval_ids ids time s t = {i \<in> ids. s \<le> time i \<and> time i < t}"

definition rate_constrained :: "'a set \<Rightarrow> ('a \<Rightarrow> nat) \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "rate_constrained ids time B r \<longleftrightarrow> (\<forall>s t. s \<le> t \<longrightarrow> card (interval_ids ids time s t) \<le> B + r * (t - s))"

theorem fetch_bound_with_delay:
  fixes grants fetches :: "'a set" and grant fetch :: "'a \<Rightarrow> nat"
  assumes finite_grants: "finite grants"
    and matching: "fetches \<subseteq> grants"
    and timing: "\<And>i. i \<in> fetches \<Longrightarrow> grant i \<le> fetch i \<and> fetch i \<le> grant i + D"
    and rate: "rate_constrained grants grant B r"
    and window: "s \<le> t"
  shows "card (interval_ids fetches fetch s t) \<le> B + r * ((t - s) + D)"
proof -
  have subset: "interval_ids fetches fetch s t \<subseteq> interval_ids grants grant (s - D) t"
  proof
    fix i
    assume A: "i \<in> interval_ids fetches fetch s t"
    then have F: "i \<in> fetches" and W: "s \<le> fetch i" "fetch i < t"
      unfolding interval_ids_def by auto
    have G: "i \<in> grants" using F matching by blast
    have T: "grant i \<le> fetch i" "fetch i \<le> grant i + D" using timing[OF F] by auto
    have "s - D \<le> grant i" "grant i < t" using W T by arith+
    with G show "i \<in> interval_ids grants grant (s - D) t" unfolding interval_ids_def by simp
  qed
  have finite_upper: "finite (interval_ids grants grant (s - D) t)"
    using finite_grants unfolding interval_ids_def by auto
  have card_le: "card (interval_ids fetches fetch s t) \<le> card (interval_ids grants grant (s - D) t)"
    using card_mono[OF finite_upper subset] .
  have lower_time: "s - D \<le> t" using window by arith
  have bound: "card (interval_ids grants grant (s - D) t) \<le> B + r * (t - (s - D))"
    using rate lower_time unfolding rate_constrained_def by blast
  have width: "t - (s - D) \<le> (t - s) + D" using window by arith
  have "B + r * (t - (s - D)) \<le> B + r * ((t - s) + D)"
    using width by (simp add: mult_le_mono)
  with card_le bound show ?thesis by arith
qed

corollary zero_delay_preserves_bound:
  assumes "finite grants" "fetches \<subseteq> grants"
    "\<And>i. i \<in> fetches \<Longrightarrow> grant i = fetch i"
    "rate_constrained grants grant B r" "s \<le> t"
  shows "card (interval_ids fetches fetch s t) \<le> B + r * (t-s)"
  using fetch_bound_with_delay[OF assms(1,2), where grant=grant and fetch=fetch and D=0 and B=B and r=r and s=s and t=t] assms(3-5) by auto

lemma example_grant_rate:
  "rate_constrained ({0,1,2} :: nat set) id 1 1"
proof (unfold rate_constrained_def, intro allI impI)
  fix s t :: nat
  assume "s \<le> t"
  have sub: "interval_ids ({0,1,2} :: nat set) id s t \<subseteq> {s..<t}"
    unfolding interval_ids_def by auto
  have "card (interval_ids ({0,1,2} :: nat set) id s t) \<le> card {s..<t}"
    by (rule card_mono[OF finite_atLeastLessThan sub])
  then show "card (interval_ids ({0,1,2} :: nat set) id s t) \<le> 1 + 1 * (t - s)"
    by simp
qed

theorem unchanged_rate_counterexample:
  "rate_constrained ({0,1,2} :: nat set) id 1 1 \<and>
   (\<forall>i \<in> ({0,1,2} :: nat set). id i \<le> (\<lambda>_. 2) i \<and> (\<lambda>_. 2) i \<le> id i + 2) \<and>
   card (interval_ids ({0,1,2} :: nat set) (\<lambda>_. 2) 2 3) > 1 + 1 * (3 - 2)"
proof -
  have E: "interval_ids ({0,1,2} :: nat set) (\<lambda>_. 2) 2 3 = {0,1,2}"
    by (auto simp: interval_ids_def)
  have C: "card (interval_ids ({0,1,2} :: nat set) (\<lambda>_. 2) 2 3) = 3"
    unfolding E by simp
  show ?thesis using example_grant_rate C by auto
qed

end
