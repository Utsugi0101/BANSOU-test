# BANSOU-test

BANSOU の E2E 検証用リポジトリです。

## 目的

- PR の変更に対して BANSOU attestation が必須になることを確認する
- `require_file_coverage: true` で変更ファイルのカバレッジ検証を確認する

## 事前設定

GitHub の Repository Variables に以下を設定してください。

- `BANSOU_ISSUER`: 例 `https://<your-worker-domain>`
- `BANSOU_JWKS_URL`: 例 `https://<your-worker-domain>/.well-known/jwks.json`

## 検証手順

1. このリポジトリでブランチを作り、`src/app.ts` を変更して PR を作成する
2. VS Code 拡張 BANSOU でクイズに合格し、`.bansou/attestations/<commit>/*.jwt` を生成する
3. 生成された `.jwt` を PR にコミットして push する
4. `Verify BANSOU Token` ジョブが成功することを確認する

## 失敗確認

- `.jwt` を削除して push すると失敗する
- 変更ファイルに対応しない token だけ残すと失敗する

## 半自動チェック

ローカルで gate 判定状態を確認できます。

```sh
BANSOU_GATE_API_TOKEN=<token> BANSOU_SUB=Utsugi0101 npm run e2e:check
```
