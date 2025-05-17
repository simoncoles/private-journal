# README


## Development testing 

```bash
ngrok http --url=dev.simon-localhost.com 3100
```

## LLM Image Processing

Image attachments are sent to OpenAI when they are added to an entry. Set the
`OPENAI_API_KEY` environment variable so the `ruby_llm` gem can authenticate:

```bash
export OPENAI_API_KEY=your_api_key
```

The LLM's response will be saved on the associated entry in the `llm_response`
column. After updating the code, run migrations to add the new column:

```bash
bin/rails db:migrate
```

