theory Correspondence_Examples
  imports Rate_Monitor Concurrent_Bot
begin

lemma monitor_refill_example:
  "monitor 2 1 (Some 2) [Send, Tick 1, Send, Other] = Some 1"
  by eval

lemma monitor_reject_absorbing_example:
  "monitor 1 0 (Some 1) [Send, Send, Tick 100] = None"
  by eval

lemma monitor_shared_example:
  "monitor 1 0 (Some 1) [Send, Send] = None \<and>
   monitor 1 0 (Some 1) [Send] = Some 0"
  by eval

end
