# Limpar

O Limpar identifica dados que as aplicações e o macOS recriam quando necessário: caches, registos, ficheiros temporários, caches do navegador e de programadores, bem como resíduos de aplicações desinstaladas. O Swabr funciona com dois tipos de regras:
- **Regras específicas** para navegadores, ferramentas de desenvolvimento (Xcode, Homebrew, npm, pip, Cargo, Gradle …) e algumas aplicações cujos dados se encontram em locais mais profundos.
- **Regras gerais** que seguem as convenções de pastas do macOS: tudo o que se encontra em «`~/Library/Caches`», as pastas de cache do Chromium em todas as aplicações Electron (Slack, Discord, VS Code, Obsidian…), caches, registos e ficheiros temporários nos contentores das aplicações. Desta forma, também são abrangidas as aplicações que não constam de nenhuma lista.

Cada regra tem o seu tipo (cache, registos, pacotes, compilação…) e a sua própria classificação. As regras específicas têm precedência sobre as gerais.

## Como funciona
- **Iniciar análise:** o Swabr apenas analisa, nada muda.
- **Verifique a lista:** as categorias e os respetivos tamanhos encontram-se à esquerda; as entradas da categoria selecionada, à direita, apresentam a classificação, o tamanho e o efeito. A caixa à frente de uma categoria seleciona todo o seu conteúdo; expanda uma linha para ver os respetivos caminhos.
- **Para o Lixo:** clique no botão no canto inferior direito e, em seguida, confirme na janela de revisão. Se a opção «Eliminar definitivamente» estiver ativada, o botão passa a chamar-se «Limpar» e a eliminação ocorre imediatamente.
- **Concluído:** a página final mostra quanto espaço foi libertado, dividido por categoria, e o espaço livre antes e depois.

## Seguro ou Rever
| Nível | Significado | Pré-selecionado |
|---|---|---|
| **Seguro** (verde) | dados de cache, registo ou temporários que são recriados | sim |
| **Rever** (laranja) | podem conter dados que ainda deseja ou que demoram muito tempo a descarregar novamente: Lixo, anexos de e-mail, estados das janelas, caches próprias do macOS, downloads de grande dimensão, como o Gradle ou o Playwright | não |

«Recomendados» seleciona apenas entradas seguras, «Todos» seleciona tudo e «Nenhum» não seleciona nada.

## Entradas ignoradas
- **«está em execução»:** os caches de uma aplicação aberta não são afetados (por exemplo, Chrome, Slack, VS Code). Isto também se aplica às regras gerais: o Swabr reconhece a aplicação pelo nome da pasta ou pelo ID do pacote. Encerre a aplicação e execute novamente a verificação.
- **Escudo verde:** a entrada está protegida (ver «Dados protegidos») ou encontra-se numa área bloqueada.

## Categorias especiais
- **Restos de aplicações removidas:** caches, registos e estados das janelas de aplicações que já não estão instaladas e que não sofreram alterações nos últimos 30 dias (ajustável). Gestores de palavras-passe, chaveiro e dados SSH estão excluídos.
- **Conjuntos de dados de grande dimensão (apenas como sugestão):** cópias de segurança do iOS, Mail, simuladores, Docker, modelos de IA. O Swabr nunca os elimina automaticamente, mas indica-lhe onde os pode limpar corretamente.

## Nunca mais terá de limpar
Clique com o botão direito do rato numa entrada → **«Nunca limpar»** protege-a permanentemente. Desfaça em Definições → Dados protegidos.

Isto também abrange tudo o que a mesma regra detetar posteriormente. Na lista expandida, clique com o botão direito do rato num local para proteger apenas esse local, todo o conteúdo de uma aplicação ou todas as pastas com esse nome. Imediatamente a seguir, **a opção «Desfazer»** na barra acima da lista revoga a proteção.

## O que muda a seguir?
As aplicações recriam as suas caches; o primeiro arranque ou o primeiro carregamento de uma página poderá demorar um pouco mais. Os inícios de sessão, documentos, definições e marcadores permanecem.
