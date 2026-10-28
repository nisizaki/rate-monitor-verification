theory Permit_Operational
  imports Permit_Delay Rate_Monitor
begin

datatype permit_event = Advance_Time nat | Grant_Permit nat | Perform_Fetch nat | Cancel_Permit nat

record permit_state =
  clock :: nat
  credit :: nat
  issued :: "nat set"
  pending :: "nat set"
  fetched :: "nat set"
  granted_at :: "nat \<Rightarrow> nat"
  fetched_at :: "nat \<Rightarrow> nat"

fun permit_bucket_event :: "permit_event \<Rightarrow> event" where
  "permit_bucket_event (Advance_Time d) = Tick d"
| "permit_bucket_event (Grant_Permit i) = Send"
| "permit_bucket_event (Perform_Fetch i) = Other"
| "permit_bucket_event (Cancel_Permit i) = Other"

inductive permit_step :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> permit_state \<Rightarrow> permit_event \<Rightarrow> permit_state \<Rightarrow> bool" where
  advance: "permit_step B r D s (Advance_Time d)
     (s\<lparr>clock := clock s + d, credit := min B (credit s + r*d)\<rparr>)"
| grant: "\<lbrakk>i \<notin> issued s; credit s > 0\<rbrakk> \<Longrightarrow>
     permit_step B r D s (Grant_Permit i)
       (s\<lparr>credit := credit s - 1, issued := insert i (issued s),
          pending := insert i (pending s), granted_at := (granted_at s)(i := clock s)\<rparr>)"
| fetch: "\<lbrakk>i \<in> pending s; clock s \<le> granted_at s i + D\<rbrakk> \<Longrightarrow>
     permit_step B r D s (Perform_Fetch i)
       (s\<lparr>pending := pending s - {i}, fetched := insert i (fetched s),
          fetched_at := (fetched_at s)(i := clock s)\<rparr>)"
| cancel: "i \<in> pending s \<Longrightarrow>
     permit_step B r D s (Cancel_Permit i) (s\<lparr>pending := pending s - {i}\<rparr>)"

inductive permit_run :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> permit_state \<Rightarrow> permit_event list \<Rightarrow> permit_state \<Rightarrow> bool" where
  nil: "permit_run B r D s [] s"
| cons: "\<lbrakk>permit_step B r D s e s'; permit_run B r D s' es s''\<rbrakk> \<Longrightarrow>
    permit_run B r D s (e # es) s''"

definition permit_valid :: "nat \<Rightarrow> permit_state \<Rightarrow> bool" where
  "permit_valid D s \<longleftrightarrow>
     finite (issued s) \<and> pending s \<subseteq> issued s \<and> fetched s \<subseteq> issued s \<and>
     pending s \<inter> fetched s = {} \<and>
     (\<forall>i \<in> pending s. granted_at s i \<le> clock s) \<and>
     (\<forall>i \<in> fetched s. granted_at s i \<le> fetched_at s i \<and>
                              fetched_at s i \<le> granted_at s i + D)"

lemma permit_step_valid:
  assumes "permit_step B r D s e s'" "permit_valid D s"
  shows "permit_valid D s'"
  using assms by (cases rule: permit_step.cases) (auto simp: permit_valid_def)

theorem permit_run_valid:
  assumes "permit_run B r D s es s'" "permit_valid D s"
  shows "permit_valid D s'"
  using assms by (induction rule: permit_run.induct) (auto dest: permit_step_valid)

lemma permit_step_projection:
  assumes "permit_step B r D s e s'"
  shows "step B r (credit s) (permit_bucket_event e) (credit s')"
  using assms
  apply (cases rule: permit_step.cases)
  apply (auto intro: step.intros)
  apply (metis One_nat_def step.send)
  done

theorem permit_run_projection:
  assumes "permit_run B r D s es s'"
  shows "run B r (credit s) (map permit_bucket_event es) (credit s')"
  using assms by (induction rule: permit_run.induct) (auto intro: run.intros permit_step_projection)

theorem permit_monitor_matches:
  assumes "permit_run B r D s es s'"
  shows "monitor B r (Some (credit s)) (map permit_bucket_event es) = Some (credit s')"
  using permit_run_projection[OF assms] run_monitor by blast

theorem operational_fetch_bound:
  assumes "permit_run B r D s es s'" "permit_valid D s"
    "rate_constrained (issued s') (granted_at s') B r" "a \<le> b"
  shows "card (interval_ids (fetched s') (fetched_at s') a b) \<le> B + r * ((b - a) + D)"
proof -
  have V: "permit_valid D s'" using permit_run_valid[OF assms(1,2)] .
  then have F: "finite (issued s')" and S: "fetched s' \<subseteq> issued s'"
    and T: "\<And>i. i \<in> fetched s' \<Longrightarrow> granted_at s' i \<le> fetched_at s' i \<and> fetched_at s' i \<le> granted_at s' i + D"
    unfolding permit_valid_def by auto
  show ?thesis using fetch_bound_with_delay[OF F S T assms(3,4)] .
qed

end
