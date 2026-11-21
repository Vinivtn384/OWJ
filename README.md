# Otimizador Windows Jaru (v25)

Utilitário modular, defensivo e reversível em PowerShell para otimização, limpeza, debloat e gestão de serviços no Windows 10/11.

## Como executar online (PowerShell)

Abre o **PowerShell** ou **Terminal** e executa o comando abaixo (a elevação para Administrador é solicitada automaticamente):

```powershell
irm "https://raw.githubusercontent.com/Vinivtn384/OWJ/main/OtimizadorWindowsJaru_v25.ps1" | iex
```



## Como executar offline (Ficheiro .bat / Pen USB)

Ideal para uso portátil em pen USB ou em computadores sem acesso à internet:

1. Clica no ficheiro **`OtimizadorWindowsJaru_v25.bat`** na lista acima e utiliza o botão **Download raw file** (ou clica no botão verde **Code** e depois em **Download ZIP** para extrair todos os ficheiros).
2. Guarda o ficheiro numa pasta local ou na pen USB e faz **duplo-clique** para iniciar.
3. Aceita o pedido de privilégios de **Administrador (UAC)**.

> **Aviso do SmartScreen:** Como o ficheiro `.bat` foi transferido da internet, o Windows Defender pode mostrar um ecrã azul de proteção na primeira execução. Clica em **Mais informações** e depois em **Executar assim mesmo**.
>
> **Nota:** Se estiveres a usar a versão de lançador separado, mantém **`OtimizadorWindowsJaru_v25.bat`** e **`OtimizadorWindowsJaru_v25.ps1`** sempre na mesma pasta.

## O que o script faz

| Opção | Módulo | Descrição |
| :---: | :--- | :--- |
| **[1]** | **Otimização Segura** | Cria Ponto de Restauro, guarda cópia de segurança do Registo/Energia, limpa ficheiros temporários, cache de navegadores (Chrome, Edge, Brave, Vivaldi, Opera/GX e Firefox) e cache DNS. |
| **[2]** | **Limpeza Avançada** | Esvazia a Reciclagem, limpa a cache do Delivery Optimization e transferências pendentes do Windows Update (`SoftwareDistribution\Download`). |
| **[3]** | **Debloat e Privacidade** | Remove bloatware seguro (mantendo Store, Media Player, Solucionadores, Fotos, Calc, Paint e Defender) e desativa Bing no Iniciar, Copilot, Widgets e anúncios. |
| **[4]** | **Serviços em Manual** | Desativa telemetria e define serviços não essenciais para arranque Manual, preservando Bluetooth, Biometria, Notificações, BitLocker e Impressão. |
| **[5]** | **Relatório Comparativo** | Mostra a diferença real de RAM livre, processos ativos, espaço em disco, ping e tempo de resolução DNS (Antes vs. Depois). |
| **[6]** | **DESFAZER** | Restaura todas as chaves de Registo, Plano de Energia e serviços (incluindo `DelayedAutoStart`) ao estado original e arquiva as cópias de segurança. |

## Segurança e Reversão

- **Onde ficam os registos e cópias de segurança:**
  - **Modo online (`irm | iex`):** guardados automaticamente em `%USERPROFILE%\OtimizadorJaru`.
  - **Modo offline (`.bat` ou `.ps1` local):** guardados na mesma pasta ou pen USB onde o ficheiro foi executado.
- **Cópia de segurança protegida:** os estados originais do Registo (`master_reg.json`), serviços (`servicos_original.json`) e plano de energia (`power_original.txt`) não são sobrescritos em execuções repetidas.
- **Para reverter:** abre novamente o utilitário e escolhe a opção **[6] DESFAZER**, ou utiliza o Ponto de Restauro criado no Windows.
