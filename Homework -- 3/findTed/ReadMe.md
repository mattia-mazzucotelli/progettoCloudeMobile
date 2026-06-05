\[Su console AWS]

Caricare i file (.zip?) sulla console CloudShell


```
$ aws sts get-caller-identity --query Account --output text
-> 572266825940

## Se la repository non è stata ancora creata
$ aws ecr create-repository --repository-name lambda-chromadb --region us-east-1 

$ aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 572266825940.dkr.ecr.us-east-1.amazonaws.com

$ docker build --platform linux/amd64 -t lambda-chromadb .

$ docker tag lambda-chromadb:latest 572266825940.dkr.ecr.us-east-1.amazonaws.com/lambda-chromadb:latest

$ docker push 572266825940.dkr.ecr.us-east-1.amazonaws.com/lambda-chromadb:latest
```



\[CREAZIONE LAMBDA]

Creare Lambda con immagine container, sfogliare le immagini e selezionare quella corretta

\[CONFIGURAZIONI]

verficare sul codice della lambada se si devono mettere delle variabili d'ambiente

