# BANSOU-test

BANSOU の E2E 検証用リポジトリです。

## 目的

- PR の変更に対して BANSOU の証明（server ledger）が必須になることを確認する
- `gate_url` モードで変更ファイルのカバレッジ検証を確認する

## 事前設定 (ledger mode)

GitHub の Repository Variables に以下を設定してください。

- `BANSOU_ISSUER`: 例 `https://<your-worker-domain>`
- `BANSOU_JWKS_URL`: 例 `https://<your-worker-domain>/.well-known/jwks.json`
- `BANSOU_GATE_URL`: 例 `https://<your-worker-domain>`

GitHub の Repository Secrets に以下を設定してください。

- `BANSOU_GATE_API_TOKEN`: `/gate/evaluate` 用トークン

## 検証手順

1. このリポジトリでブランチを作り、`src/app.ts` を変更して PR を作成する
2. VS Code 拡張 BANSOU でクイズに合格する（proofStorageMode は `serverOnly` 推奨）
3. `npm run e2e:check` で `ok:true` になることを確認する
4. `Verify BANSOU Token` ジョブが成功することを確認する

## 失敗確認 (ledger mode)

- クイズ未合格のまま push すると `missing_files` で失敗する
- `BANSOU_GATE_API_TOKEN` が不正なら 401 で失敗する

## 半自動チェック

ローカルで gate 判定状態を確認できます。

```sh
BANSOU_GATE_API_TOKEN=<token> BANSOU_SUB=Utsugi0101 npm run e2e:check
```

注意:
- `BANSOU_GATE_API_TOKEN=...` と `BANSOU_SUB=...` の間に必ず半角スペースを入れてください。
- スクリプトは先に `GET /gate/health` を確認し、サーバー未準備を警告します。
