# Direitos de administrador (serviço auxiliar)

## O que é isto?
Algumas etapas requerem direitos de administrador: a remoção de aplicações que pertencem ao sistema, otimizações como a limpeza da cache DNS e a leitura dos elementos de início de sessão que as próprias aplicações registaram. Sem o serviço auxiliar, o macOS solicita a sua palavra-passe sempre que necessário.

**O serviço auxiliar** do Swabr assume estas etapas assim que o tiver autorizado. Apenas aceita pedidos do Swabr assinados com o mesmo certificado de programador e encerra após cinco minutos de inatividade. Está disponível apenas na edição Direct.

## Como configurar
### 1. Configure-o no Swabr
Abra **o Swabr → **Definições** → **Comportamento** e clique em **Configurar…** na secção **Direitos de administrador****.

![](images/helfer-1-einstellungen.png)

### 2. Autorize-o nas Definições do Sistema
No macOS, abra «**Definições do Sistema» → «Geral» → «Elementos de início de sessão**». Na secção **«Atividade em segundo plano das aplicações**», ative **** **Swabr** e confirme com a sua palavra-passe ou Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Concluído
De volta ao Swabr, a secção **«Direitos de administrador»** indica «Configurado: já não é necessária qualquer palavra-passe». A partir de agora, estas etapas são executadas sem solicitar a palavra-passe.

> Se aparecer a mensagem «A aguardar a sua autorização nas Definições do Sistema», a etapa 2 ainda não foi concluída. A **roda dentada** ao lado desta mensagem leva-o diretamente para lá.

## O que muda a seguir?
- **Apps → Arranque** também mostra as aplicações que se registam automaticamente (por exemplo, com a opção «Abrir ao iniciar sessão» na aplicação).
- **Desinstalar**, **Otimizar** e os passos que requerem acesso de root em **Limpar**, **Projetos**, **Instaladores** e **Reduzir** já não solicitam a palavra-passe.
- As verificações de segurança permanecem inalteradas: todos os bloqueios fixos continuam a aplicar-se e cada etapa é verificada e registada.

## Remover
Clique em **«Remover»** em «**Definições**»** → «Comportamento» → «Direitos de administrador**». O Swabr voltará então a solicitar a palavra-passe em cada etapa.
