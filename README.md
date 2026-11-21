# Otimizador Windows Jaru (v25)

Utilitário modular, defensivo e reversível em PowerShell para otimização, limpeza, debloat e gestão de serviços no Windows 10/11.

## Como executar online (PowerShell)

Abra o **PowerShell** ou **Terminal** e execute o comando abaixo (a elevação para Administrador é solicitada automaticamente):

```powershell
irm "[https://raw.githubusercontent.com/Vinivtn384/Otimizador_Windows_Jaru/main/OtimizadorWindowsJaru_v25.ps1](https://raw.githubusercontent.com/Vinivtn384/Otimizador_Windows_Jaru/main/OtimizadorWindowsJaru_v25.ps1)" | iex
```

> **Windows 10 antigo (erro de TLS/SSL):**
> ```powershell
> [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm "[https://raw.githubusercontent.com/Vinivtn384/Otimizador_Windows_Jaru/main/OtimizadorWindowsJaru_v25.ps1](https://raw.githubusercontent.com/Vinivtn384/Otimizador_Windows_Jaru/main/OtimizadorWindowsJaru_v25.ps1)" | iex
> ```

## Como executar offline (Arquivo .bat / Pendrive)

Ideal para uso portátil em pendrive ou em computadores sem acesso à internet:

1. Clique no arquivo **`Otimizador_Jaru_v25.bat`** na lista acima e use o botão **Download raw file** (ou clique no botão verde **Code** → **Download ZIP** e extraia os arquivos).
2. Salve o arquivo em uma pasta local ou no pendrive e dê um **duplo-clique** para iniciar.
3. Aceite a solicitação de privilégios de **Administrador (UAC)**.

> **Aviso do SmartScreen:** Como o arquivo `.bat` foi baixado da internet, o Windows Defender pode exibir uma tela azul de proteção na primeira execução. Clique em **Mais informações** e depois em **Executar assim mesmo**.
>
> **Nota:** Se estiver usando a versão de lançador separado (`Iniciar_Otimizador_v25.bat`), mantenha o `.bat` e o `OtimizadorWindowsJaru_v25.ps1` sempre na mesma pasta.

## O que o script faz

| Opção | Módulo | Descrição |
| :---: | :--- | :--- |
| **[1]** | **Otimização Segura** | Cria Ponto de Restauração, salva backup do Registro/Energia, limpa temporários, cache de navegadores (Chrome, Edge, Brave, Vivaldi, Opera/GX e Firefox) e cache DNS. |
| **[2]** | **Limpeza Avançada** | Esvazia a Lixeira, limpa o cache do Delivery Optimization e downloads pendentes do Windows Update (`SoftwareDistribution\Download`). |
| **[3]** | **Debloat e Privacidade** | Remove bloatware seguro (mantendo Store, Media Player, Solucionadores, Fotos, Calc, Paint e Defender) e desativa Bing no Iniciar, Copilot, Widgets e anúncios. |
| **[4]** | **Serviços em Manual** | Desativa telemetria e define serviços não essenciais para inicialização Manual, preservando Bluetooth, Biometria, Notificações, BitLocker e Impressão. |
| **[5]** | **Relatório Comparativo** | Exibe o delta real de RAM livre, processos ativos, espaço em disco, ping e tempo de resolução DNS (Antes vs. Depois). |
| **[6]** | **DESFAZER** | Restaura todas as chaves de Registro, Plano de Energia e serviços (incluindo `DelayedAutoStart`) ao estado original e arquiva os backups. |

## Segurança e Reversão

- **Onde ficam os logs e backups:**
  - **Modo online (`irm | iex`):** salvos automaticamente em `%USERPROFILE%\OtimizadorJaru`.
  - **Modo offline (`.bat` ou `.ps1` local):** salvos na mesma pasta ou pendrive onde o arquivo foi executado.
- **Backup mestre protegido:** os estados originais do Registro (`master_reg.json`), serviços (`servicos_original.json`) e plano de energia (`power_original.txt`) não são sobrescritos em execuções repetidas.
- **Para reverter:** abra o utilitário novamente e escolha a opção **[6] DESFAZER**, ou utilize o Ponto de Restauração criado no Windows.
