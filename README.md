https://github.com/bonsai/plagger



add Publish::Slack
https://github.com/miyagawa/plagger/pull/13




add Filter::LLM

- module: Filter::LLM
  config:
    api_key: YOUR_API_KEY
    # デフォルトをFlashにして節約、特定のフィードだけProにする
    model: gemini-1.5-flash
    rules:
      - title_match: "重要論文"
        model: gemini-1.5-pro
