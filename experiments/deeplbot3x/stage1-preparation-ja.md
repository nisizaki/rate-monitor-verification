# 第1段階：xiamen候補の固定と実環境評価の準備
2026-10-28。準備・資料更新のみ。設定変更、deploy、投稿、reaction、翻訳、使用量API呼出、スケジュール自動化、OS/ネットワーク設定変更は未実施。

## 1. 候補と公開状況
研究repo mainの85b78b544f5dfa1d5f846a16dcb0db44ca2abc41を再fetch確認し、別環境の追加commitはなかった。yamatoの別修正を取り込んでいない。xiamen候補をこのcommitのpatchとして固定し、将来mainが進んでも自動的に実験へ取り込まない。競合候補が現れた場合は別path/branchとprovenanceで分離し、混合しない。
実験base: b4eb35ba464ebde9e4fad89c387c68653cc76dac
公開experiment.patch SHA-256:
63aca6729e5084d715194fea20cecaab7d393acf15fe67f3673d2d4d19c63ffb
ローカルruntime 36ファイル集約SHA-256:
86c34b8e4e4d1c8e9adc9affee4fb5ca980b862d4f452987d40862c0e11a56da
local runtime hash再照合成功。公開patchはlocal app関連付けを除外しているので両hashは別範囲。remote deployed codeのhashは未取得。依存lockfileなしの制約は残る。
公開patchのclean base適用とソースhash一致、Deno165件（通常155+故障10）、Python7件、fmt/lint成功はvalidation.jsonに記録済み。今回はruntimeを変えておらず再テストは不要。公開済み対象11ファイルを実Slack ID、メール、私的環境名/path、tokenパターンで再検査し該当なし。自動検査の検出限界はある。既存READMEのupstreamリポジトリ名・研究履歴は改変しない。

## 2. 私的対象と設定
xiamen WSL Ubuntu /path/to/isolated-experiment。
App APP_ID / org ORG_ID / workspace WORKSPACE_ID / channel CHANNEL_ID / trigger TRIGGER_ID。
既存DeepLbot3は対象外。app/trigger/keyを再作成しない。

以下は全てNOT RUN、後日確認後のみ:
    cd /path/to/isolated-experiment
    export PATH="/path/to/experimental-tools/deno-2.9.8:/path/to/experimental-tools/slack-4.11.0/bin:$PATH"
    export DENO_DIR=/path/to/experimental-tools/deno-cache
    slack env set DEEPL_API_URL https://api-free.deepl.com/v2/translate --app APP_ID --team ORG_ID --skip-update --no-color
    slack platform deploy --app APP_ID --team ORG_ID --manifest-source local --hide-triggers --skip-update --no-color

事前にlocal対象1件、hosted/deployed、remote名・grant・既存trigger・channel・emojiとmanifest差分を確認。envの「app environment variable」成功を必要とし、local .env fallbackなら停止。hosted一覧は名前のみでFree URL現在値を証明しない。設定成功は将来値の設定であり過去値の検証ではない。キーは変更しない。
deployはDeveloperAppInstallを含む更新経路。translateに加えmonthly_usage_report_workflow/test_monthly_usage_report_workflowと共有bundleへ影響し得る。追加scope要求、別app、新規作成、grant選択、承認pending、想定外差分なら停止。--forceと--org-workspace-grantを使わない。--hide-triggersはinstallを省かない。exit0だけで有効化済みと扱わない。

各mode変更窓は入力を休止し、前の実行を突合してから次のUUIDを固定:
    TRIAL_UUID=$(python3 -c 'import uuid; print(uuid.uuid4())')
    slack env set EXPERIMENT_TRIAL_ID "$TRIAL_UUID" --app APP_ID --team ORG_ID --skip-update --no-color
    slack env set EXPERIMENT_MODE baseline --app APP_ID --team ORG_ID --skip-update --no-color
record/monitorは最後の値を替える。試行開始前から結果突合までmode/trial/config hashを固定。設定更新は原子的でないため混在/反映不明なら入力を始めない。
現候補のtrialはenv単位。1試行1UUIDにするなら試行ごとのenv更新・反映待ちが必要で、15秒間隔を満たせるとは未確認。block単位trial+run対応へ変える場合も曖昧な対応付けを成功とせず、pilot前に設計判断する。実験中のruntime自動改変はしない。

## 3. ログ・永続状態・再開設計
これは実装済みrunnerではなく、第3段階までに検証する設計。今は自動試行や常駐サービスを作成しない。
私的notesにappend-only JSONL台帳を置き、schema_version、連番、UTC、phase(smoke/pilot/main)、day/session/order/mode、planned_trial_id、attempt_id、retry_of、code/config hashes、予定codepoints、stateを保存する。runtime run_idはFunction生成値で、ローカル計画IDとは別に記録する。再開時に既存IDを作り直さない。
状態はplanned→intent_post→post_ack→intent_reaction→reaction_ack→function_seen→reply_seen/result_seen/log_parsed→resolved。各外部操作前にintentをappend+flush+fsyncしてから送信し、応答後にもappend+fsync。排他lockで単一writerに制限。status snapshotは同一filesystemでtemp書込+fsync+renameし、可能なら親directoryもfsyncする。破損末尾は隔離して保持し、勝手に成功/未実行へ変更しない。
外部操作とlocal記録は原子的でない。応答前断線やtimeoutはuncertainで、未実行とは扱わず自動再送しない。公開APIのidempotency保証が未確認なのでexactly-onceを約束しない。既存投稿/反応/Function結果を許可された最小範囲で照会し、確認できるまで当該trialを凍結する。再実行は別attempt_idとretry_of、別承認・追加予算で記録する。
Slack message timestamp/必要なID対応表は私的notesだけ、0600ファイル/0700ディレクトリ、Git外。本文・翻訳文・token/key/headerはそこにも保存しない。私的対応表を公開成果物へコピーしない。
実ログadapterは未検証。collectorはbounded JSONL/JSON message wrapperを処理するが、CLI activity出力がそのまま適合するとは未確認。raw出力をtee/保存せず、読み取り範囲・wrapper・秘密値除外を確認したadapterでallowlist filterへ渡す。対象外channel historyは取得しない。
    python3 safe_log_filter.py --trial-id "$TRIAL_UUID" --mode baseline --expected-invocations 1
run_id/trial不正は拒否、null時間/文字数は分布・合計から除外、全件文字数欠測はnull。operator_planは独立分母ではない。rawプラットフォームログの保存をこのコマンドで正当化しない。

## 4. 外出先の進捗確認
既存の会話経路で、phase/session、予定/開始/完了/失敗/欠測/uncertain数、最終更新UTC、現在の停止理由、code hashだけのprivate sanitized snapshotを伝える。今の承認で新しい公開dashboard、VPN、ポート開放、常駐remote access、OS電源/ネットワーク設定を作らない。会話から自動的に定期通知される仕組みはまだ設定していない。
xiamenを稼働・接続可能に保つ運用は実行前チェックに入れる。通信断・suspend後は台帳照合と対象/config再確認が終わるまで再開しない。remote進捗経路自体が切れた場合も台帳を保持し、復旧後に同じ会話へsnapshotを提示する。

## 5. 段階・件数と文字数
第2段階は3mode各1回のsmokeだけ。既存案は非公開の固定合成文8codepoints×3=24。性能差の証拠ではない。1trial最大120秒で結果待ちを打切り、収集180秒で打切るがhosted処理をキャンセルしない。
第3段階pilotは最大30回、mainと分離。自動/半自動の可否、設定反映時間、追跡・再開、欠測、使用量、試行間隔を確認してからmain確定案を再レビューする。
第4段階候補は3日×4session×3mode×10=360。pilot30+main360=390だが、smoke3を加えると393回。各100codepoints上限ならpilot+main39000、smokeも100上限で数える保守的総枠39300。8文字smokeを固定する場合は39024。いずれも提出入力の計画値でありAPI課金文字数ではない。再試行分は含まず、別予算なしに追加しない。
12sessionに6順序(BRM/BMR/RBM/RMB/MBR/MRB)を各2回割り当てる。日/時間帯との偏りを抑える割当をpilot後に固定。各modeに同一合成入力集合を使い、本文は公開せずinput_set_versionと長さを記録。15秒の開始間隔は仮案で、設定反映・前trialの完了・Slack制約・重なり次第で延ばす。今はschedule/automationを作らない。
集計ではphaseを混ぜず、mode×session×dayの成功/失敗/欠測/uncertain、elapsed_ms/translation_ms/observer_msのn,p50,p95,p99と測定境界を示す。観測できた標本だけで完全性や総数を推定しない。

## 6. 提案する停止閾値（実行前レビュー対象）
- 対象app/workspace/channel/emoji/config hash不一致1件: 即停止。
- 1trialから2件以上の起動/reply、record/monitorでfetch>1、monitor accepted=false: 即停止し追加入力をしない。
- HTTP429/456または認証/権限エラー1件: 即停止。その他機能失敗は連続2件でsession停止。smokeでは失敗/不明1件で次modeへ進まない。
- smokeのstart/result/translation/correlation欠測1件: 即停止。pilot/mainでは連続2trialで終端ログ欠落、または直近10trialの20%以上で必須ログ欠落なら停止。run_id/trial不正、未知の結果、intent後のuncertainは1件でも当該再送と次の設定変更を保留する。
- 使用量確認の増分が同じ確認区間の全承認済み提出codepoints累計+100を超える、または次session計画予算+1000の残量を確認できない: 一旦停止して他利用・反映遅延・重複を調査。閾値は異常検出の提案であり課金等価の主張ではない。
- 通信断/状態保存失敗/lock競合: 新規入力停止。既送信の処理を未実行扱いにしない。
usageは本人のhidden-input helperまたは公式UIでpilot/session前後に確認し、必要な数値・時刻・account-wide provenanceだけ私的台帳へ記録。自動でhosted keyを抽出/再利用しない。無人usage監視経路は未構築。これが必要なら別途安全な認証設計を承認する。

## 7. 停止・復旧
投稿/反応の停止とlocal collector停止は、hosted処理や既存triggerを止めない。
後日別承認でEXPERIMENT_MODE=disabledへ変更する方法は、候補コードの新規翻訳をguardで止める候補だが、Function起動・進行中処理の停止ではない。反映と旧deployed codeの同一性も未確認。
CLI4.11.0のtrigger/platformにはpause/stopがなく、trigger delete/updateやapp uninstallは別承認のremote変更。既存trigger保持/再作成禁止のため削除は採用しない。既起動hosted処理の安全なキャンセル手段は確認できていない。
旧source/artifactがないのでrollback可能とは言えない。manifest snapshotは比較資料であり旧codeを復元しない。既知候補の再deployは旧版復元とは別。結果不明時は状態照会し、自動再deploy/rollback・trigger再作成・key取消しをしない。

## 8. 判断と承認の区切り
今回の完了範囲は固定候補/検証証拠/手順/状態管理設計。第2段階へ移る前に、(a)Free URL/mode/trialのremote変更、(b)既存appのmanifest/install更新を含むdeploy、(c)事前/事後の対象・activation・adapter確認、(d)各mode1回のsmokeと失敗時停止、をまとめて確認する。pilot/mainの開始許可とは分離する。
durable runner、実ログadapter、env反映待ちの検証はまだ未完。これらを実装・offline fault-testしてからpilotへ進む。旧版復旧保証や独立分母も未確立。
baselineには共通計測負荷、観測完全性はunknown、monitorはper Functionのみ。実測をTypeScript全体の形式的証明やFunction間の共有レート保証として扱わない。
