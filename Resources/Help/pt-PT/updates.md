# Atualizações de aplicações

O Swabr verifica se existem novas versões para todas as aplicações instaladas. Requisito: as **informações online** têm de estar ativadas (Definições → Geral).

## Fontes
| Fonte | Detecção | Edição direta | Edição da App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | abrir o site |
| App Store | Comparação com a App Store | A App Store abre a sua página de atualizações | o mesmo |
| O canal de atualização da aplicação (Sparkle) | appcast do fornecedor | descarrega e instala a nova versão | abrir o site |
| Fornecedor (catálogo Homebrew) | comparação de versões | Transferências do fornecedor e instalações | abrir o site |

## Segurança durante a instalação (Direta)
Um download só substitui uma aplicação se a **soma de verificação** corresponder, se a **assinatura do programador** for idêntica à da aplicação instalada e se o **Gatekeeper** concordar. A versão antiga é enviada para o Lixo. As aplicações em execução são encerradas após um aviso e reabertas posteriormente.

## Como utilizar
- Um de cada vez com «Atualizar», ou vários com **caixas de seleção** e «**Atualizar** os selecionados».
- O menu ⋯ oculta uma atualização.
- «Atualizadas» e «Não é possível verificar» apresentam a lista dos restantes aplicações; as aplicações web do Safari não têm atualizações.

> As aplicações provenientes de instaladores .pkg abrem o Instalador do macOS; conclua a instalação nesse local.
