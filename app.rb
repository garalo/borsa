require 'sinatra'
require 'httparty'
require 'json'
require 'date'
require 'erb'

set :public_folder, File.dirname(__FILE__) + '/public'

get '/' do
  begin
    # Kullanıcıdan gelen sembolü al ve temizle
    input_symbol = params[':symbol']&.upcase&.strip || 'THYAO'
    @display_symbol = input_symbol.gsub('.IS', '')

    # Zaman dilimi parametresi
    time_range = params[:range] || '6mo'
    @selected_range = time_range
    
    # Zaman dilimi etiketleri
    @range_labels = {
      '1wk' => '1 Hafta',
      '1mo' => '1 Ay', 
      '3mo' => '3 Ay',
      '6mo' => '6 Ay',
      '1y' => '1 Yıl',
      '2y' => '2 Yıl'
    }

    # API çağrısı için URL oluşturma
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{@display_symbol}.IS"

    headers = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Accept" => "application/json",
      "Referer" => "https://finance.yahoo.com"
    }

    query = {
      interval: '1d',
      range: time_range
    }

    response = HTTParty.get(url, headers: headers, query: query)

    if response.code == 404
      @error_message = "Hisse senedi bulunamadı: #{@display_symbol}. Lütfen doğru hisse kodunu girdiğinizden emin olun."
      return erb :index
    elsif !response.success?
      @error_message = "API Hatası (#{response.code}): Lütfen daha sonra tekrar deneyin."
      return erb :index
    end

    data = JSON.parse(response.body)
    return "Veri bulunamadı" if data.nil?

    timestamps = data.dig("chart", "result", 0, "timestamp")
    opens = data.dig("chart", "result", 0, "indicators", "quote", 0, "open")
    highs = data.dig("chart", "result", 0, "indicators", "quote", 0, "high")
    lows = data.dig("chart", "result", 0, "indicators", "quote", 0, "low")
    closes = data.dig("chart", "result", 0, "indicators", "quote", 0, "close")
    volumes = data.dig("chart", "result", 0, "indicators", "quote", 0, "volume")

    @price_data = timestamps&.each_with_index.map do |ts, i|
      {
        date: Time.at(ts).strftime("%Y-%m-%d"),
        open: opens[i],
        high: highs[i],
        low: lows[i],
        close: closes[i],
        volume: volumes[i]
      }
    end&.compact || []

    erb :index
  rescue JSON::ParserError => e
    "JSON Parse Hatası: API'den geçersiz yanıt alındı"
  rescue StandardError => e
    "Bir hata oluştu: #{e.message}"
  end
end
