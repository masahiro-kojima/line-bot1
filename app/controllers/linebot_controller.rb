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
        # 現在地
         when Line::Bot::Event::MessageType::Location
        # 緯度
          latitude = event.message['latitude']
          # 軽度
          longitude = event.message['longitude']
          appId = "c793c2fa6eac6556fed8f41167fcc68a"
                    # 天気url                                           緯度　　　　　　軽度　　　　　　　id
          url= "http://api.openweathermap.org/data/2.5/forecast?lon=#{longitude}&lat=#{latitude}&APPID=#{appId}&units=metric&mode=xml"
                # 開く
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          # 取得
          xpath = 'weatherdata/forecast/time[1]/'
          # 現在天気
          nowWearther = doc.elements[xpath + 'symbol'].attributes['name']
          # 現在気温
          nowTemp = doc.elements[xpath + 'temperature'].attributes['value']
          # 現在天気
          case nowWearther
          # 晴
          when /.*(clear sky|few clouds).*/
            push = "現在地の天気は晴れです\u{2600}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
          # 曇り
          when /.*(scattered clouds|broken clouds|overcast clouds).*/
            push = "現在地の天気は曇りです\u{2601}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
            # 雨
          when /.*(rain|thunderstorm|drizzle).*/
            push = "現在地の天気は雨です\u{2614}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
            # 雪
          when /.*(snow).*/
            push = "現在地の天気は雪です\u{2744}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
            # 霧
          when /.*(fog|mist|Haze).*/
            push = "現在地では霧が発生しています\u{1F32B}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
            # それ以外の天気
          else
            push = "現在地では何かが発生していますが、\nご自身でお確かめください。\u{1F605}\n\n現在の気温は#{nowTemp}℃です\u{1F321}"
          end
        # テキスト
        when Line::Bot::Event::MessageType::Text
                    input = event.message['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          min_per = 30
      　case input
          # 明日
        when /.*(明日|あした).*/
		      # 降水確率
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
	    　     # もし　　降水確率　　30        または　　　降水確率　　　　
           if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
	          	# 雨が降る
              push =
                "明日の天気だよね。\n明日は雨が降りそうだよ(>_<)\n今のところ降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
           else
	       #	雨は降らない
              push =
                "明日の天気？\n明日は雨が降らない予定だよ(^^)\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
           end
　　# # 　明後日
  #       when /.*(明後日|あさって).*/
	 #     	# 降水確率
  #           per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
  #           per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
  #           per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
  #           if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
　　# 　　    # 雨が降る
  #             push =
  #               "明後日の天気だよね。\n何かあるのかな？\n明後日は雨が降りそう…\n当日の朝に雨が降りそうだったら教えるからね！"
　　#       # 　あめは降らない
  #           else
  #             push =
  #               "明後日の天気？\n気が早いねー！何かあるのかな。\n明後日は雨は降らない予定だよ(^^)\nまた当日の朝の最新の天気予報で雨が降りそうだったら教えるからね！"
  #           end
  #   # 　かわいいなど
  #         when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
		# # ありがとう
  #           push =
  #             "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
	 #   # こんにちは
  #         when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*
		# # こんにちは
  #           push =
  #             "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
  #     # 　適当なテキスト
  #         else
  #         # 降水確率
  #           per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
  #           per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
  #           per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
  #     # 　降水確率　　　　
  #           if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
  #           #雨
  #             word =
  #               ["雨だけど元気出していこうね！",
  #               "雨に負けずファイト！！",
  #               "雨だけどああたの明るさでみんなを元気にしてあげて(^^)"].sample
		#           # 雨
  #             push =
  #               "今日の天気？\n今日は雨が降りそうだから傘があった方が安心だよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word}"
  #           else
		# 　　　　# 晴れ
  #             word =
  #               ["天気もいいから一駅歩いてみるのはどう？(^^)",
  #               "今日会う人のいいところを見つけて是非その人に教えてあげて(^^)",
  #               "素晴らしい一日になりますように(^^)",
  #               "雨が降っちゃったらごめんね(><)"].sample
		#     　　# 晴れ　　　　　　
  #             push =
  #               "今日の天気？\n今日は雨は降らなさそうだよ。\n#{word}"
  #           end
  #         end
　　# 　現在地、テキスト以外
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
      # 返信
        message = {
          type: 'text',
                # 送信する
          text: push
        }
        #　　　　返答　　　　　　　　　　　　　返信
    client.reply_message(event['replyToken'], message)
        
        # フォロー
      when Line::Bot::Event::Follow
       
        line_id = event['source']['userId']
            # 作る
        User.create(line_id: line_id)
      # アンフォロー
      when Line::Bot::Event::Unfollow
        
        line_id = event['source']['userId']
                                      # 消す
        User.find_by(line_id: line_id).destroy
      end
    end
    head :ok
  end


  private
# クライアント
  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end

