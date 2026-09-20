# 静かな夜間配達 / Night Delivery Prototype

Roblox向けの最小プロトタイプです。

## 今できること

- 夜の小さな街をスクリプトで自動生成
- 配達所で荷物を受け取る
- 5軒から配達先をランダム選択
- 配達先を黄色いハイライトとマーカーで表示
- 60秒のタイムボーナス
- 配達完了でCoinsを獲得
- 次の配達を繰り返せる
- PC / モバイル共通のProximityPromptを利用

## ゲームループ

1. 配達所の黄色いカウンターで「配達を受ける」
2. 指定された家へ移動
3. 家の前で「配達する」
4. Coins獲得
5. 配達所へ戻って次の依頼

早く届けるほど報酬が増えます。

## Roblox Studioへ入れる方法

### 方法A: Rojoを使う

このフォルダで:

```bash
rojo serve
```

Roblox Studio側でRojoプラグインを接続してください。

### 方法B: 手動

1. `src/ServerScriptService/NightDelivery.server.lua` の内容を Roblox Studio の `ServerScriptService` に Script として貼る
2. `src/StarterPlayer/StarterPlayerScripts/NightDelivery.client.lua` の内容を `StarterPlayer > StarterPlayerScripts` に LocalScript として貼る
3. Play を押す

マップはサーバースクリプトが自動生成するので、空のBaseplateでも動作確認できます。

## MVPなのでまだ入れていないもの

- 自転車
- セーブ
- 天候
- ショップ
- 課金
- 複数人専用の協力ギミック
- ランダムな道路生成
- 本格的な街のアセット

まずは「荷物を受け取る → 目的地へ行く → 報酬」が楽しいかだけを確認する構成です。

## 次に足す候補

1. 自転車
2. 配達報酬で速度アップ
3. 新地区の解放
4. 雨・霧・深夜などの条件
5. レア依頼
6. バッグや自転車のコスメ
