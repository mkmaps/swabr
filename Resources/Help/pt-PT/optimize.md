# Otimizar

O Otimizar executa tarefas de manutenção para o macOS. Os passos desnecessários são ignorados, indicando o motivo.

## Como utilizar
- Selecione as tarefas com **as caixas de seleção**; «Selecionar tudo/nada» no canto superior direito. O Swabr memoriza as tarefas não selecionadas.
- Cada tarefa descreve o que faz e quais as alterações que ocorrem na sequência. Laranja: efeito secundário percetível.
- **Palavra-passe:** as tarefas que requerem direitos de administrador são executadas em conjunto; a palavra-passe é solicitada apenas uma vez. Ao cancelar, apenas essas tarefas são ignoradas.

## As tarefas
| Tarefa | O que acontece | Palavra-passe |
|---|---|---|
| Pré-visualizações do QuickLook | repor a cache de miniaturas do QuickLook | não |
| Estados das janelas | remover janelas guardadas com mais de 30 dias, exceto para aplicações em execução | não |
| Preferências danificadas | Mova os ficheiros de preferências de terceiros danificados para o Lixo | não |
| Cache de DNS | limpar a resolução de nomes (ignorado se houver uma VPN ativa ou se estiver offline) | sim |
| Rotas de rede | limpar a tabela de encaminhamento e renovar endereços via DHCP, apenas se todas as interfaces utilizarem DHCP (pequena interrupção) | sim |
| .DS_Store | não há ficheiros do Finder em unidades de rede e USB | não |
| Opções de ajuste antigas | App Nap e verificação de imagens restabelecidas aos valores predefinidos | não |
| Permissões | redefina as permissões na sua pasta pessoal, apenas se houver algum problema (demora alguns minutos) | sim |
| Índice do Spotlight | verifique o estado, reconstrua apenas em caso de erros ou quando a indexação estiver desativada | sim |
| Exclusões do Spotlight | relatar exclusões cujo local já não existe; lê as definições com direitos de administrador, não altera nada | sim |
| Manutenção periódica | apenas os períodos com prazos a cumprir; já não estão presentes desde o macOS 26 | sim |
| Barra lateral e itens recentes | Mover as listas ilegíveis da barra lateral e dos itens recentes para o Lixo | não |
| Verifique o volume de arranque | verifique o sistema de ficheiros, não altera nada | não |
| Elementos de início de sessão | relatar entradas cujo programa está em falta | não |
| Histórico de transferências | limpar o histórico de transferências do Gatekeeper (privacidade) | não |
| Serviços em segundo plano | notificar sobre serviços cujo programa está em falta | não |
| Notificações | eliminar notificações entregues com mais de 30 dias | não |
| Bases de dados | compactar o Mail, o Safari e as Mensagens (apenas se estiverem fechados, intactos e com menos de 100 MB) | não |

## Edição da App Store
Nessa versão, apenas estão disponíveis as tarefas que funcionam na sua pasta pessoal sem direitos de administrador: estados das janelas, preferências corrompidas, barra lateral e itens recentes, histórico de transferências e serviços em segundo plano.
