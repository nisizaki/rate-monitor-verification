# 修正候補のデプロイ前手順（準備のみ）
以下のremote変更・deploy・実試行は未実行。別途承認後に1段階ずつ行う。既存DeepLbot3を選択しない。新規app/trigger/keyを作らない。

## 対象と識別
実行場所はisolated WSL Ubuntuの /path/to/isolated-experiment。
対象App APP_ID、組織ORG_ID、workspace WORKSPACE_ID、channel CHANNEL_ID、既存trigger TRIGGER_ID。
ローカル36ファイルの識別: 86c34b8e4e4d1c8e9adc9affee4fb5ca980b862d4f452987d40862c0e11a56da。
公開パッチ: 63aca6729e5084d715194fea20cecaab7d393acf15fe67f3673d2d4d19c63ffb。
公開パッチはlocal app設定を除外し、故障回帰テストをclone内に移動している。source-identity.jsonの個別hashで一致を確認。remote artifactのhashではない。

## 使用量の本人確認
録画・端末ログ・shell tracingを停止した私用対話端末で以下を実行する。キーを引数、環境変数、チャットへ渡さない。隠し入力が使えない場合はスクリプトが停止する。キーを再登録・置換しない。
    python3 /path/to/private-notes/check_deepl_free_usage.py
既存スクリプトはgetpassで入力し、TLS検証付きhttps://api-free.deepl.com/v2/usageへGETを1回送る。proxyとredirectを無効化、15秒timeout、数値項目だけ出力、失敗詳細は抑制。Pythonメモリの完全消去は保証しない。こちらは実行しない。
character_count/character_limitは当該請求期間のアカウント使用量/上限。反映に数分かかり得る。他利用を含むため差分も本試行だけへ帰属できない。本人確認結果はローカル別資料に置き、公開repoにアカウント使用量を載せない。成功してもhosted appが同じキー・Free URLを使っている証明にはならない。

## 変更前チェック
1. 現在のlocal hashを照合し、.slack/apps.jsonが対象deployed app1件だけであることを確認。想定外の差分は停止。
2. remote名、Installed、workspace grant、既存triggerと対象channel/emojiを確認。既存keyの値を取得しない。hosted env listは名前のみでありFree URL現在値を確認できない。
3. manifestのscope/domain/function/workflow/datastore差分をレビュー。現状の非秘密snapshotと既存ログ証拠を保存。旧ソースがないためrollbackできるとは判断しない。
4. 変更窓には指定反応を他者が付けないよう調整し、進行中/待機中の試行がないことを確認。不明なら開始しない。

## 後日承認対象のコマンド（NOT RUN）
以下はCLI4.11.0のhelpと公式ソースで構文/分岐を確認した。秘密値を渡すコマンドは含まない。
    cd /path/to/isolated-experiment
    export PATH="/path/to/experimental-tools/deno-2.9.8:/path/to/experimental-tools/slack-4.11.0/bin:$PATH"
    export DENO_DIR=/path/to/experimental-tools/deno-cache

Free URL設定（既存keyは変更しない）:
    slack env set DEEPL_API_URL https://api-free.deepl.com/v2/translate --app APP_ID --team ORG_ID --skip-update --no-color

hosted判定とdeployed選択が必要。成功表示が「app environment variable」であることを確認。「project environment variable」や.env作成ならlocal fallbackでありremote成功ではないため停止。設定しても過去の現在値を検証したことにはならない。全Functionへ共有されるenvの変更である。

デプロイ:
    slack platform deploy --app APP_ID --team ORG_ID --manifest-source local --hide-triggers --skip-update --no-color

local manifest差分の承認後のみ。CLI内部はDeveloperAppInstallを含む既存app更新経路を通り、純粋なuploadではない。新規app、別ID、workspace grant選択、scope増加、admin approval pending、想定外manifest差分が出たら停止。--force/--org-workspace-grantを付けない。--hide-triggersは生成promptを省くがinstall処理を省かない。
影響はtranslate_reaction_workflowに加えmonthly_usage_report_workflowとtest_monthly_usage_report_workflow、対応Function、共有lib/datastoreを含むbundle全体。既存scopeはreactions:read/write、chat:write、emoji:read、users:read/email、channels:history、groups:history、datastore:read/write、files:write。今回の修正自体は追加scopeを必要としないが、実際のmanifest差分は別途確認する。
exit0/upload成功だけで有効化済みとはしない。deployment activity/状態を確認し、同じapp/grant/triggerの保持と承認保留の有無を確認。remote code hash未取得の限界を明記して実入力前で止める。

各試行の設定（baseline→record→monitorを手動で1つずつ。ループ禁止）:
    TRIAL_UUID=$(python3 -c 'import uuid; print(uuid.uuid4())')
    slack env set EXPERIMENT_TRIAL_ID "$TRIAL_UUID" --app APP_ID --team ORG_ID --skip-update --no-color
    slack env set EXPERIMENT_MODE baseline --app APP_ID --team ORG_ID --skip-update --no-color

record/monitor時はそれぞれ新しいUUIDを作り、最後の値をrecord/monitorに替える。各2更新の間と完了後の反映確認前は入力しない。env更新の原子性や反映遅延は保証しない。実ログのmode/trialが期待と違えば混在として停止。workspace/channel/emoji/keyは再設定しない。

## 各1回のスモーク手順（NOT RUN）
- 各modeの新規メッセージ本文は同一の合成文非公開の固定合成文（8 Unicodeコードポイント、改行なし）。本文にemojiや識別子を足さず、投稿IDとの対応は私的台帳で管理する。
- 1投稿・指定実験emojiの1リアクションだけ。1 mode最大8提出文字、全3 mode合計24文字の計画上限。これは課金上限の強制機構ではない。platform再配送/他利用は別リスク。
- 直前にapp、workspace/channel、既存trigger、実験専用emoji、mode/trial、guardが一致していることを確認。不明なら投稿しない。対象外データを収集しない。
- 設定を固定したまま1件の起動/結果を観測する。投稿から最大120秒、ログ収集は最大180秒で打ち切る。この待ち時間はhosted実行をキャンセルしない。自動再投稿・リアクション再追加・翻訳再試行はしない。
- 機能成功: 対象の起動1件、結果translated、期待する英訳replyと完了反応を確認。翻訳本文をログ保存しない。HTTP429/456、timeout、partial result、失敗結果、重複reply/複数起動/追加fetchは失敗または安全上の停止条件。
- 観測判定は機能判定と別: 同じtrial/run、開始/結果各1件、translation_result 1件、連番/emit_failures/欠測を確認。record/monitorはfetch1件、monitor accepted=trueを期待。baselineのfetchは「観測なし」で0件成功とは扱わない。
- null、欠落、invalid ID、重複、collector拒否、遅延で突合不能なら観測不十分。機能成功でも観測成功としない。文字数・時間の欠測を0に置換しない。機能の失敗/不確実性や観測不足があれば次modeへ進まず報告。
- 3件終了後は本実験へ進まず、各modeの機能/観測/文字数/使用量由来/エラーを報告。投稿を自動削除しない。

## 中止・停止・復旧の区別
A. 試験中止: 新たな投稿/反応をやめる。すでに起動したhosted処理は止まらない。
B. ローカル収集停止: collectorやactivityのプロセスを終了する。hosted app/triggerは動き続ける。
C. 将来の翻訳をguardで止める候補: 後日別承認で EXPERIMENT_MODE を無効値disabledに設定する。
    slack env set EXPERIMENT_MODE disabled --app APP_ID --team ORG_ID --skip-update --no-color
候補コードのガードが有効な新規Functionはexperiment_filteredになる。triggerからの起動自体や進行中処理は止めず、反映時点も保証しない。現在deployedコード同一性を確認できない段階では、この効果も断定しない。
D. event-trigger起動自体の停止: CLI4.11.0のtrigger/platformヘルプにpause/stopはない。公式trigger deleteは存在するが破壊的で、既存trigger保持・再作成禁止と両立しないため今回の手順には採用しない。trigger updateやapp uninstallもremote変更で影響レビューと別承認が必要。未確認のUI無効化手順を案内しない。
E. すでに実行中のhosted処理: このCLIで安全にキャンセルする操作は確認できていない。端末終了やログ停止で止まるとは言わない。
F. 復旧: snapshotはmanifest/関連付け/設定名の比較に使えるが、旧実行コードを復元できない。既知のローカル候補の再deployは同候補の再適用であり旧版rollbackではない。旧artifact/sourceが確保できるまで旧版復旧は未証明。timeout等の結果不明時は状態照会を先に行い、自動再deploy/rollback・trigger削除再作成・key取消しはしない。

公式根拠:
https://developers.deepl.com/api-reference/usage-and-quota/check-usage-and-limits
https://github.com/slackapi/slack-cli/blob/v4.11.0/cmd/env/set.go
https://github.com/slackapi/slack-cli/blob/v4.11.0/internal/pkg/apps/install.go
https://docs.slack.dev/tools/slack-cli/reference/commands/slack_platform_deploy/
https://docs.slack.dev/tools/slack-cli/reference/commands/slack_trigger_delete/
