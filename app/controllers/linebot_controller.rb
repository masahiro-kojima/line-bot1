class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 30
          case input
            # 「明日」or「あした」というワードが含まれる場合
          when /.*(明日|あした).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            # もしどれかの時間帯で降水確率30%を超えていたら
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              # 雨が降りそうだとメッセを送る
              push =
                "明日の天気だよね。\n明日は雨が降りそうだよ(>_<)\n今のところ降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            　　# 降水確率が30%未満だったら
            else
              # 雨が降らないと出力
              push =
                "明日の天気？\n明日は雨が降らない予定だよ(^^)\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            end
            # 明後日or あさってとメッセがきたら
          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            # 降水確率が30%を超えていたら
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              # 雨が降りそうだと出力
              push =
                "明後日の天気だよね。\n何かあるのかな？\n明後日は雨が降りそう…\n当日の朝に雨が降りそうだったら教えるからね！"
                # 降水確率30%未満だったら
            else
              # 腫れそうだと出力する
              push =
                "明後日の天気？\n気が早いねー！何かあるのかな。\n明後日は雨は降らない予定だよ(^^)\nまた当日の朝の最新の天気予報で雨が降りそうだったら教えるからね！"
            end
          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
            push =
              "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
            # 適当なテキストがおくられてきたら
          else
            # 降水確率を出力する
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            # もしどれかの時間帯で降水確率30%を超えていたら
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              word =
                ["雨だけど元気出していこうね！",
                 "雨に負けずファイト！！",
                 "雨だけどああたの明るさでみんなを元気にしてあげて(^^)"].sample
                # 降水確率と雨であることを出力する
              push =
                "今日の天気？\n今日は雨が降りそうだから傘があった方が安心だよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word}"
            # 降水確率が30%未満だったら
            else
              word =
                ["天気もいいから一駅歩いてみるのはどう？(^^)",
                 "今日会う人のいいところを見つけて是非その人に教えてあげて(^^)",
                 "素晴らしい一日になりますように(^^)",
                 "雨が降っちゃったらごめんね(><)"].sample
                # 雨が降りそうにないことを伝える
              push =
                "今日の天気？\n今日は雨は降らなさそうだよ。\n#{word}"
            end
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
        
      #         # 位置情報が送られてきた時
      #   when Line::Bot::Event::MessageType::Location
　　　　　　# # LINEの位置情報から緯度経度を取得
      #     latitude = event.message['latitude']
      #     longitude = event.message['longitude'] 　　　
      #     # 取得したapi
      #     appId = "c793c2fa6eac6556fed8f41167fcc68a"          
      #     # 天気取得先のurl
      #     url= "http://api.openweathermap.org/data/2.5/forecast?lon=#{latitude}&lat=#{longitude}&APPID=#{appId}&units=metric&mode=xml"
      #   # XMLをパースしていく
      #     xml  = open( url ).read.toutf8
      #     doc = REXML::Document.new(xml)
      #     xpath = 'weatherdata/forecast/time[1]/'
      #     nowWearther = doc.elements[xpath + 'symbol'].attributes['name']
      #     nowTemp = doc.elements[xpath + 'temperature'].attributes['value']
      #     case nowWearther
      #     when /.*(clear sky|few clouds).*/
      #       push = "現在地の天気は晴れです\u{2600}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
      #     when /.*(scattered clouds|broken clouds|overcast clouds).*/
      #       push = "現在地の天気は曇りです\u{2601}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
      #     when /.*(rain|thunderstorm|drizzle).*/
      #       push = "現在地の天気は雨です\u{2614}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
      #     when /.*(snow).*/
      #       push = "現在地の天気は雪です\u{2744}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
      #     when /.*(fog|mist|Haze).*/
      #       push = "現在地では霧が発生しています\u{1F32B}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
      #     else
      #       push = "現在地では何かが発生していますが、\nご自身でお確かめください。\u{1F605}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
      #     end

        
        message = {
          type: 'text',
          text: push
        }
        # メッセージを返す。
        client.reply_message(event['replyToken'], message)
        
        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    end
    head :ok
  end


  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end