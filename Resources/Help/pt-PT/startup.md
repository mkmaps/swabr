# Arranque: elementos de início de sessão e serviços

## Abrir ao iniciar sessão (Direto)
Cada aplicação instalada possui um botão **«Abrir ao iniciar sessão**». O macOS abre as aplicações ativadas após o início de sessão. O botão mais pequeno **«Oculta»** inicia-as sem abrir uma janela. Trata-se da mesma lista que se encontra em Definições do Sistemas → Geral → Elementos de início de sessão; o Swabr controla-a através dos «Eventos do Sistema» (o macOS solicita autorização uma única vez).

## Serviços em segundo plano
Abaixo (expansível) encontram-se os atualizadores e as ferramentas auxiliares que as aplicações configuram por si próprias (LaunchAgents/LaunchDaemons):
- **Os seus serviços** (na sua pasta pessoal): permitir/bloquear o arranque, remover (Lixo).
- **Serviços a nível do sistema:** apenas visualização; altere-os nas «Definições do Sistema». Exceção: se o respetivo programa estiver em falta, a opção **«Remover…»** elimina-os (o macOS solicita a sua palavra-passe).
- **«Programa em falta»:** o serviço aponta para uma aplicação eliminada e já não realiza qualquer ação – pode ser removido.

## Remoção de entradas órfãs
Os elementos de início de sessão e os serviços cuja aplicação já não se encontra instalada são assinalados a laranja com **a mensagem «Programa em falta**».
- No caso de um elemento de início de sessão, a opção **«Remover da lista»** elimina a entrada dos elementos de início de sessão.
- No canto inferior direito, **«Remover órfãos (número) …»** remove todos de uma só vez, após apresentar a lista de nomes para confirmação.
- Os ficheiros de serviço vão para o Lixo e podem ser restaurados a partir daí. O Swabr remove serviços a nível do sistema apenas se o respetivo programa tiver sido efetivamente eliminado.

## Edição da App Store
A edição da App Store não pode controlar os Eventos do Sistema, nem iniciar ou parar serviços. Mostra os seus próprios serviços em segundo plano e pode removê-los; gere os Elementos de início de sessão através do botão para as Definições do Sistema.
