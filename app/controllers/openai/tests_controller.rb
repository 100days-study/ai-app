class Openai::TestsController < ApplicationController
  def index
    # ゲームのトップページ
  end

  def play
    user_question = params[:question]
    target_word = params[:target_word]  # お題の言葉
    @result = play_game(user_question, target_word)
    puts @result
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def play_game(user_question, target_word)
    # 質問文の長さによる点数計算
    length_score = [ 100 - user_question.length, 0 ].max

    # OpenAIに質問を投げてレスポンスを取得
    generated_text = ask_openai(user_question)

    # お題との関連性のスコアを計算（関連性が高いほど低点）
    relevance_score = calculate_relevance(generated_text, target_word, user_question)
    puts "relevance_score"
    puts relevance_score

    # 合計点数
    total_score = length_score + relevance_score

    # 勝利条件
    if generated_text.include?(target_word)
      {
        win: true,
        message: "あなたの勝ちです！",
        length_score: length_score,
        relevance_score: relevance_score,
        total_score: total_score,
        generated_text: generated_text # 生成されたテキストを含める
      }
    else
      {
        win: false,
        message: "残念！お題の言葉は見つかりませんでした。",
        length_score: length_score,
        relevance_score: relevance_score,
        total_score: total_score,
        generated_text: generated_text # 生成されたテキストを含める
      }
    end
  end


  def ask_openai(user_question)
    client = OpenAI::Client.new
    prompt = "自然な話し言葉で返答してください。質問: #{user_question}"

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",  # 使用するモデルを指定
        messages: [ { role: "user", content: prompt } ],  # チャット形式でメッセージを送信
        max_tokens: 150,  # 最大トークン数を指定
        temperature: 0.7  # 創造性の度合い
      }
    )
    response["choices"][0]["message"]["content"]  # 生成されたテキストを返す
  end

  def calculate_relevance(generated_text, target_word, user_question)
    # お題の言葉を直接含む場合はペナルティを適用
    if user_question.include?(target_word)
      return 0  # もしお題を含む場合は、関連性スコアを0にする（ペナルティ）
    end

    # Embedding APIを使って生成されたテキストとお題の埋め込みを取得
    generated_embedding = get_embedding(generated_text)
    target_embedding = get_embedding(target_word)

    # コサイン類似度を計算
    similarity_score = cosine_similarity(generated_embedding, target_embedding)

    # 類似度スコアを逆転させて、関連性が高いほど低点となるようにする
    relevance_score = (1 - similarity_score) * 100  # 1 - 類似度で逆転させてスコアを計算
    relevance_score
  end

  # Embedding APIを使って埋め込みベクトルを取得
  def get_embedding(text)
    client = OpenAI::Client.new
    response = client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",  # 使用する埋め込みモデル
        input: text  # 埋め込みを計算するテキスト
      }
    )
    response["data"][0]["embedding"]  # 埋め込みベクトルを返す
  end

  # コサイン類似度を計算するヘルパーメソッド
  def cosine_similarity(vec1, vec2)
    # numpyのようなベクトル計算を行うために、Rubyの配列操作を使用
    dot_product = vec1.zip(vec2).map { |x, y| x * y }.sum
    magnitude1 = Math.sqrt(vec1.map { |x| x**2 }.sum)
    magnitude2 = Math.sqrt(vec2.map { |x| x**2 }.sum)
    (dot_product / (magnitude1 * magnitude2)).round(3)
  end
end
