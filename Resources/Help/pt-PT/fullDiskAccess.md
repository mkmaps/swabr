# Acesso total ao disco

## O que é isto?
O macOS protege alguns dados de forma especial: Mail, Mensagens, Safari, o Lixo, as cópias de segurança do Time Machine e os dados de algumas aplicações. Os programas só têm acesso a estas pastas se lhes conceder «**Acesso total ao disco**». Trata-se de uma funcionalidade de segurança do macOS, não de algo inventado pelo Swabr.

## Por que razão o Swabr necessita disso?
Sem isso, algumas partes do seu Mac permanecem ocultas:
- **Limpar: o Caixote** do Lixo, os anexos de e-mail, as caches nos contentores das aplicações e as pré-visualizações das Mensagens ficam invisíveis.
- **Armazenamento:** pastas como o Mail ou o Safari são apresentadas com tamanhos demasiado pequenos ou não são apresentadas de todo («+» após o tamanho).
- **Otimização:** as bases de dados do Mail, do Safari e do Messages, bem como os dados de utilização, ficam fora do alcance.

O Swabr funciona sem isso, mas deteta menos elementos.

## O que é que o Swabr pode fazer com isso?
O acesso permite a leitura e a escrita. O Swabr utiliza-o apenas para as regras que vê na aplicação e só elimina após a sua confirmação na janela de revisão. As restrições fixas aplicam-se sempre: o iCloud Drive, o Keychain, os Documentos, o Ambiente de Trabalho e tudo o que estiver fora da sua pasta pessoal nunca são afetados. Cada eliminação é registada no Histórico.

## Como conceder acesso
### 1. Abra as Definições do Sistema
Clique na **roda dentada** no aviso laranja do Swabr (ou na janela aquando do primeiro arranque). Abrir-se-á «**Definições do Sistema» → «Privacidade e segurança» → «Acesso total ao disco**».

### 2. Ative o Swabr
Ative **o** **Swabr OP.app** e confirme com a sua palavra-passe ou Touch ID. Se a entrada não estiver presente, adicione o Swabr com ** botão +** ou arraste a aplicação do Finder para a lista.

![](images/festplattenvollzugriff-1-liste.png)

### 3. Reinicie o Swabr
O macOS normalmente solicita-lhe que o faça. O aviso laranja desaparece então.

> Se mover o Swabr ou instalar uma versão recém-assinada, o macOS poderá tratá-lo como uma nova aplicação. Remova a entrada antiga com **−** e adicione o Swabr novamente.

## Revogação
Desative-a na mesma lista. O Swabr volta a apresentar o aviso e funciona com menos acesso.

## Edição da App Store
A edição da App Store não utiliza o «Acesso total ao disco», mas sim autorizações de pastas (consulte «Edição direta e edição da App Store»).
