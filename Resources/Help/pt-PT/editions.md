# Edição Direta e App Store

O Swabr está disponível em duas edições, desenvolvidas a partir do mesmo código. Pode verificar qual delas possui em Definições → Geral e na secção «Acerca».

|  | Direto | App Store |
|---|---|---|
| Distribuição | GitHub (DMG) | Mac App Store |
| Acesso | pasta pessoal completa com Acesso total ao disco | apenas as pastas a que conceder acesso |
| Limpar, desinstalar | sim | sim, após conceder |
| Aplicações pertencentes ao sistema | sim (o Finder solicita a sua palavra-passe) | sim (o macOS solicita a sua palavra-passe) |
| Ficheiros do sistema em /Library | sim | Sim, após conceder acesso à pasta /Library |
| Otimizar | todas as 19 tarefas | 5 tarefas sem direitos de administrador |
| Atualizações | instala as atualizações automaticamente | mostra atualizações, abre a App Store ou o site do fornecedor |
| Arranque | gerir elementos de início de sessão e serviços | Mostrar e remover os seus próprios serviços em segundo plano |
| Reduzir o tamanho | sim | não |

## Por que razão a versão da App Store tem menos funcionalidades
A Apple exige uma **«sandbox»** para a App Store: as aplicações só podem aceder às pastas que lhe foram concedidas, não podem solicitar direitos de administrador, não podem instalar ou alterar outras aplicações e não podem controlar outras aplicações (Diretrizes de Revisão da App Store 2.4.5 e 2.5.2). O Swabr cumpre estas regras e oferece tudo o que estas permitem.

## Conceder acesso a pastas (edição da App Store)
Na primeira vez que abrir as secções «Limpar», «Otimizar» ou «Aplicações», surge a mensagem «Permitir acesso». Clique em «Conceder…»; a caixa de diálogo já apresenta a pasta correta, bastando apenas confirmar. As autorizações são guardadas e podem ser revogadas em Definições → Acesso.

## Versão Direct e código-fonte
O Swabr é software livre ao abrigo da licença MIT. A versão Direct e o código-fonte completo estão disponíveis gratuitamente no GitHub; a ligação encontra-se em Definições → Sobre.
