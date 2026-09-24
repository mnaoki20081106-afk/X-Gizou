# リモートブラウザ（無料VM向け）

Xをサーバーの本物のChromiumで開き、iPhoneから画面を遠隔操作します。
iPhone側のWebViewはリモート操作画面だけを表示し、XのJavaScriptを実行しません。
Xが利用するのはサーバーのLinux・Chromium・フォント・描画環境・送信元IPです。
Windows/Androidを実際に動かす構成ではありません。GPUなしではソフトウェア描画になり得ます。
この構成ではローカルのUA/フィンガープリント設定をリモートへ送信・注入しません。

## 無料で動かす場所

Oracle Cloud Always Freeの対象VMを確保できれば利用可能です。
2026-09-24に確認した英語公式資料では、A1無料枠は合計2 OCPU・12 GB相当です。
必ず自分のコンソールのAlways Free表示と割当残量を確認してください。
無料VMの在庫不足やアイドル回収があり、常時稼働・永久無料を保証する構成ではありません。
有料枠への自動切替や、回収を避けるための疑似負荷は組み込みません。

Cloudflare Browser Run無料枠は1日10分で、日常的なリモート操作には適しません。
VM、アカウント、接続情報はこのリポジトリには含まれず、まだデプロイされていません。

## 起動

前提: Always Free対象Linux VM、Docker Engine/Compose、Tailscaleを用意し、
VMとiPhoneを自分のTailscaleアカウントへ接続します。
Tailscaleは個人利用の無料対象範囲を確認してください。
VMへの接続はOracleのCloud Shell/コンソール接続からも行えます。

VMでこのリポジトリのremoteディレクトリに移動して:

```sh
docker compose config --quiet
docker compose up -d
tailscale serve --bg http://127.0.0.1:3000
tailscale serve status
```

Tailscale Serveが案内するHTTPS URLを、アプリの「プロフィール → 編集 →
実行環境 → リモートブラウザ」に入力します。HTTPS有効化の案内が出たら、
自分のTailscale管理画面で有効化します。iPhone側でもTailscaleに接続します。

この構成はインターネット公開ではなく、自分のtailnet内からのアクセスです。
ブラウザポートは127.0.0.1だけに公開しています。3000/3001を外部に開放したり、
Funnelに変更したりしないでください。ブラウザ操作画面はログイン済みXを操作できるため、
Tailscaleのアクセス権は自分の信頼できるデバイスだけに限定してください。
サーバー管理者はブラウザデータへアクセスできるので、第三者の公開ブラウザは使いません。

## プロフィールと更新

- ログインデータはDockerの`browser-profile`ボリュームに永続化します。
- 同じURLは同じブラウザです。アプリのプロフィールだけを増やしてもサーバー側は分離しません。
- 複数プロフィールには別コンテナ・別ボリューム・別の専用接続先を用意します。
- アプリの削除・Cookie削除でサーバー側データは消えません。リモートブラウザ内でログアウト・データ削除します。
- `docker compose down`はデータを残します。`down -v`はログイン情報も削除するため通常は使用しません。
- ブラウザ更新は`docker compose pull`のあと`docker compose up -d`。`latest`を固定したい場合は確認済みイメージのdigestへ変更してください。
- フォントはコンテナに実際に入っているものです。架空の一覧を返しません。
- 送信元IPはサーバーのものです。住宅回線IPになったり、Xに保存された過去の関連付けが消えたりはしません。

## 検証状態

アプリはGitHub ActionsでReleaseビルドと設定・移行テストを行います。
CIでは一時的なLinuxコンテナの起動も確認します。実VM上での起動、iPhoneでのストリーミング・文字入力・Xログインは、
実際のVM確保後に検証が必要です。未検証の状態を稼働済みとは扱いません。

## 公式資料

- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- https://docs.linuxserver.io/images/docker-chromium/
- https://tailscale.com/docs/features/tailscale-serve
- https://developers.cloudflare.com/browser-run/pricing/
