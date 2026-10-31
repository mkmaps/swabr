# Projetos

A funcionalidade «Projetos» remove pastas de compilação e de dependências dos seus projetos de software, por exemplo, `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` e mais 27 tipos.

## Locais de pesquisa
Por predefinição: ~/dev, ~/Projects, ~/GitHub, ~/Code e outras pastas habituais. Adicione as suas com **Adicionar pasta…** na parte superior, também em unidades externas. A pesquisa vai até 6 níveis de profundidade (ajustável).

## Regras de segurança
- Apenas pastas dentro de um projeto (com `package.json`, `Cargo.toml`, `go.mod`, `Package.swift` e outros).
- As pastas com ficheiros controlados pelo Git ou ficheiros de chave (`*-keypair.json`) permanecem inalteradas.
- `bin` apenas em projetos .NET, `vendor` apenas com PHP/Composer.
- As pastas utilizadas nos últimos 7 dias são assinaladas e não vêm pré-selecionadas (ajustável).

## Posteriormente
Cada linha indica como recuperar a pasta (por exemplo, `npm install`, `cargo build`). Por predefinição, são eliminadas de forma definitiva; está disponível a opção «Mover para o Lixo».
