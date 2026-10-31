# Desinstalar aplicações

Arrastar uma aplicação para o Lixo deixa para trás os seus dados: caches, definições, serviços em segundo plano e, por vezes, ficheiros do sistema. O Swabr localiza estes resíduos.

## Como funciona
- Selecione as aplicações à esquerda com a **caixa de seleção** (é possível selecionar várias). As informações e todos os ficheiros encontrados aparecem à direita.
- **Desinstalar…** abre a janela de revisão com todos os efeitos.
- As aplicações em execução são encerradas primeiro. Tudo vai para o **Lixo**.

## O que é removido?
| Grupo | Exemplos | Pré-selecionado |
|---|---|---|
| **Será removido** | aplicação, caches, registos, estado da janela, agentes de arranque | sim |
| **Dados pessoais** | configurações, contentores, contas, bibliotecas | não |
| **Sensível** | perfis do navegador (palavras-passe, histórico), dados de grupos de aplicações | nunca automaticamente |
| **Ficheiros do sistema** | ficheiros em /Library, serviços do sistema, ferramentas auxiliares | não, requer palavra-passe |

Os dados pessoais permanecem por predefinição, pelo que as definições e as contas são recuperadas caso reinstale a aplicação. «Remover também o resto» seleciona-os. Altere a predefinição em Definições → Comportamento.

## Sobre a aplicação
A secção «Informações» apresenta o programador (a partir da assinatura), a categoria, a versão, a última utilização e — caso existam informações online — uma descrição e ligações para o site, a App Store e a pesquisa na Web. Isto ajuda-o a reconhecer aplicações desconhecidas antes de as eliminar.

## Símbolos
- **Cadeado:** protegido (componente do sistema, software de segurança com o seu próprio programa para desinstalar, o próprio Swabr).
- **Chave:** pertence a outro utilizador ou ao sistema; o macOS solicita a sua palavra-passe ao eliminar.

## Homebrew
As aplicações instaladas com o Homebrew são removidas com o comando `brew uninstall`, para que o Homebrew se mantenha sincronizado.
