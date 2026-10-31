# Dados protegidos (lista de permissões)

A lista em Definições → **Dados protegidos** define o que o Swabr **nunca** altera durante a limpeza — mesmo que uma regra o incluísse de outra forma. Outras ferramentas chamam a isto uma «lista de permissões».

## Como ler a lista
- **Ativar = protegido.** A entrada deixa de aparecer na opção «Limpar» ou aparece com um escudo verde.
- **Desativar = pode ser eliminado** se uma regra de limpeza o incluir.
- **«Padrão»** indica entradas protegidas por predefinição (caches do Gradle, navegadores do Playwright, modelos do Hugging Face).
- Cada entrada indica quanto espaço ocupa neste momento, para que possa ver qual é o custo de a proteger.

## Quando proteger
Proteja dados que são recriados, mas cuja recriação demora muito tempo ou consome um grande volume de dados: o DerivedData do Xcode de um projeto de grande dimensão, caches do Gradle, modelos de IA descarregados e downloads do Homebrew numa ligação lenta.

## As suas próprias entradas
Em «As suas entradas», pode proteger qualquer pasta ou ficheiro:
- **A opção «Escolher pasta…»** abre uma caixa de diálogo; a pasta selecionada fica protegida.
- Ou digite um **padrão**. Abaixo dele, verá imediatamente quantos itens correspondem a esse padrão.

| Padrão | Protege |
|---|---|
| `~/Library/Caches/Foo` | exatamente esta pasta |
| `~/Library/Caches/Foo/*` | tudo o que se encontra nesta pasta (e, com ela, a própria pasta) |
| `~/Library/Caches/Foo*` | todas as pastas que comecem por «Foo» |

«~» é a sua pasta pessoal, «*» representa quaisquer caracteres.

## Regras de segurança
Algumas entradas estão sempre protegidas e não podem ser desativadas: caches que contêm o estado de sincronização do iCloud, o início de sessão na Conta Apple, o Wallet, o Home, os tipos de letra, o Spotlight ou as transferências em segundo plano em curso, bem como a própria cache do Swabr. Além disso, o iCloud Drive, o Keychain, os Documentos, o Ambiente de Trabalho e tudo o que se encontre fora da sua pasta pessoal estão sempre fora dos limites.

## Localização e reinicialização
A lista está armazenada em `~/.config/swabr/whitelist` (um padrão por linha). Assim que alterar algo, este ficheiro substitui a lista predefinida; a opção «Redefinir para os valores predefinidos» volta a eliminá-la.
