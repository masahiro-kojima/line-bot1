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
          push="ねる"
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
      # 返信
        message = {
          type: 'text',
                # 送信する
          text: push
        }
        #　　　　返答　　　　　　　　　　　　　　　返信
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

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end




