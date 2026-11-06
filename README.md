# claude-statusline

Claude Code 用のカスタム2行ステータスライン（`statusline-command.sh`）および RunCat Neo メトリクス連携スクリプト（`runcat-statusline.py`）です。

絵文字を使わず ANSI カラーとミニマルなセパレーターで構成された高速・多機能な2行ステータスラインを表示します。

## 表示項目

### 1行目：ワークスペース・Git・モデル・トークン統計
- **Workspace**: 現在の作業ディレクトリ名
- **Language**: プロジェクトの言語自動検知（`node` / `python` / `go` / `rust`）
- **Git**: リポジトリ名 (`owner/repo`)、ブランチ名、追加/削除行数 (`+added -removed`)、未コミット変更数 (`dirty:N`)
- **Model**: 使用中のモデル名
- **Tokens**: 累計入力・出力トークン数 (`in:` / `out:`)
- **Cache**: プロンプトキャッシュヒット率 (`cache:%`)
- **Tools**: 有効なプラグイン＋MCPサーバーの合計数 (`tools:N`)

### 2行目：システムリソース・コスト・レートリミット・コンテキスト
- **Time & Sys**: 現在時刻、CPU使用率 (`cpu:%`)、メモリ使用量 (`ram:G`)、バッテリー残量 (`batt:%`)
- **Cost & Activity**: セッション累計コスト (`$0.0000`)、当日のメッセージ数 (`msgs:N`)
- **Rate Limits**: 5時間制限 (`5h:%`)・7日間制限 (`7d:%`) の使用率とリセットまでの残り時間 (`rem:...`)
- **Context Window**: コンテキスト使用率プログレスバー (`■`/`□`)・パーセンテージ・残りトークン数 (`rem:...`)

## ファイル一覧

| ファイル名 | 配置先 | 説明 |
| :--- | :--- | :--- |
| **`statusline-command.sh`** | `~/.claude/statusline-command.sh` | メインのステータスライン描画スクリプト |
| **`runcat-statusline.py`** | `~/claude/runcat-statusline.py` | RunCat Neo Custom Metrics 用 JSON (`~/claude/runcat-usage.json`) の非同期書き出しスクリプト |
| **`settings.example.json`** | `~/.claude/settings.json` (抜粋) | Claude Code の `statusLine` 設定サンプル |

## セットアップ手順

### 1. 依存ツールの確認
スクリプト内で `jq`、`bc`、`node`、`python3` を使用します。

```bash
brew install jq
```

### 2. スクリプトの配置と実行権限の付与

```bash
mkdir -p ~/.claude ~/claude
cp statusline-command.sh ~/.claude/statusline-command.sh
cp runcat-statusline.py ~/claude/runcat-statusline.py
chmod +x ~/.claude/statusline-command.sh ~/claude/runcat-statusline.py
```

### 3. `~/.claude/settings.json` への設定追加

`~/.claude/settings.json` に以下を追加します（[settings.example.json](./settings.example.json) 参照）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
```
