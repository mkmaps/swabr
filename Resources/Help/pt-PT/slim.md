# Reduzir

Muitos aplicativos são «universais» e contêm código para Macs com Intel e com Apple Silicon. Um Mac com um chip da Apple necessita apenas de parte desse código. Reduzir remove a parte relativa à Intel.

## Que aplicações?
Apenas aplicações assinadas com um ID de Desenvolvedor, de que seja o proprietário, que não sejam da App Store, que não sejam da Apple, que não estejam configuradas para «Abrir utilizando o Rosetta» e que não estejam a ser executadas. Todas as outras são listadas em «Ignorados», com a respetiva justificação.

## Quão seguro é isto?
- Cada aplicação é otimizada a partir de uma **cópia**.
- A cópia substitui o original apenas se mantiver o seu código para o Apple Silicon, se a assinatura do código for válida, se tiver sido assinada pelo mesmo programador e se o Gatekeeper concordar.
- O original vai para o **Lixo**.

## Efeitos
A aplicação passa então a funcionar apenas em Macs com Apple Silicon, deixando de funcionar com o Rosetta ou em Macs com processador Intel. Uma atualização da aplicação restabelece o código Intel. Apenas na edição direta.
