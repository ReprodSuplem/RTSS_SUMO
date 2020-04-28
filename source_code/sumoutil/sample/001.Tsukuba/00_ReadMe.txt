%%  -*- Mode: Memo -*-
=begin

= 001.Tsukuba サンプル

== Map

=== TsukubaCentral.00.orig.*

    * つくば中心部。つくば駅、研究学園駅を中心に、東大通り・西大通り・
      平塚通り・野田線・サイエンス大通りを含む。

    * OSM からダウンロードしてきたそのまま。
    
=== TsukubaCentral.01.marked.*

    * 00.orig に、いくつか地物を追加。

    * POI
      * つくば駅、研究学園駅、イイアス、JAXA、AIST中央・西・東、NIMS北・南。

    * Zone
      * 筑波大、竹園地区、春日地区、松代地区、並木地区。


== シミュレーション設定ファイル

=== tsukuba.00.*

    * DemandFactoryMixture を使って、単純なSAVSシミュレーションを行うもの。

=== tsukuba.01.*

    * DemandFactoryAgent のテスト。

    * 複数 SAVS 運行者(Base+Allocator)のテスト。

    * 東大通りの北の端が、なぜか dead-end なのをしょりできないので、手動で削除。



        

