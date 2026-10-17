# Laboratório Windows 7 SP1 x64 offline

## Estado verificado neste host

Ubuntu 24.04.5 x64; Intel i5-1135G7 com VT-x; 15 GiB RAM (~10 GiB disponíveis na
inspeção), 92 GiB livres. /dev/kvm acessível fora do sandbox, KVM_GET_API_VERSION
retornou 12. QEMU 8.2.2 oficial Ubuntu extraído **localmente**, sem serviços,
libvirt, grupos ou mudanças de BIOS/partições/permissões globais. Bibliotecas
ficam em `.build-cache/qemu-local/`; script ajusta LD_LIBRARY_PATH só do filho.

Foi criado `.legacy-vm/win7.qcow2`, capacidade 32 GiB, alocação inicial ~328 KB,
snapshot `blank-before-os`. QMP confirmou `kvm: enabled=true/present=true`,
`status=prelaunch`, paused. A VM vazia foi encerrada; não ficou processo ligado.
**Nenhum Windows foi instalado.** Não se localizou ISO Windows nos diretórios
Downloads, Documents/projetos pesquisados, /mnt ou /media. Licença/mídia Windows
não foi fornecida; não baixar imagens de espelhos, modificações ou ativadores.

## Preparação quando houver mídia legítima

Pacotes oficiais necessários (se não houver extração local): qemu-system-x86,
qemu-system-gui, qemu-utils, seabios e genisoimage. libvirt/Virt-Manager são
opcionais e não necessários ao script. Não há compartilhamento de USB/FTDI/COM.

```sh
# Cria só se não existir; nunca sobrescreve o disco preparado.
python3 scripts/win7-vm.py init
# Inspecionar os argumentos sem iniciar:
python3 scripts/win7-vm.py plan --iso /caminho/midia-legitima.iso
# Iniciar instalação, GUI local (requer backend gráfico QEMU instalado):
python3 scripts/win7-vm.py start --iso /caminho/midia-legitima.iso
# Nas próximas inicializações, disco existente, sem ISO/rede:
python3 scripts/win7-vm.py start
```

Configuração: BIOS SeaBIOS, máquina PC/i440fx, CPU Nehalem, 2 vCPU, 3072 MiB,
IDE, VGA padrão, RTC local. `-nic none`: nem adaptador de rede virtual, nem NAT,
bridge, encaminhamento, VNC TCP ou serviço no LAN. QMP apenas socket UNIX dentro
da pasta privada do laboratório. Não habilitar internet para atualizar Win7:
transferir somente instaladores/atualizações legítimos necessários por CD ISO.
O script recusa segundo processo ativo e sobrescrita do QCOW2. Sem autostart.

## Confirmar antes de testar

No convidado, Prompt e PowerShell nativos (não instalar WMF):

```cmd
ver
wmic os get Caption,Version,CSDVersion,OSArchitecture
powershell.exe -NoProfile -Command "$PSVersionTable; [Environment]::Version"
```

Exigir Professional SP1 x64 / 6.1.7601 / PS 2.0 / CLR2, registrar diferenças.
Desligar pelo menu Windows ou, com guest rodando, enviar ACPI:

```sh
python3 scripts/win7-vm.py status
python3 scripts/win7-vm.py shutdown
```

Confirmar que o processo encerrou antes de snapshot. Não usar kill/quit como
procedimento normal nem editar imagens em uso. Se o sistema não responder,
preservar diagnóstico e decidir a interrupção explicitamente.

```sh
python3 scripts/win7-vm.py snapshot --name win7-sp1-ps2-clean
# Antes de pré-requisitos/instalação, outro snapshot com o guest desligado:
python3 scripts/win7-vm.py snapshot --name before-rc2-install
# Restore substitui estado do convidado; fazer só deliberadamente, após backup:
python3 scripts/win7-vm.py restore --name win7-sp1-ps2-clean
```

## Transferência controlada e testes

Preparar pasta só com fontes/fixtures e candidato necessários (sem logs de
clientes/credenciais). `genisoimage -J -r -o .legacy-vm/transfer.iso <pasta>`;
passar `--transfer .legacy-vm/transfer.iso` na inicialização. ISO é somente
leitura, sem diretório host compartilhado. Não anexar discos/dispositivos reais.
Remover o CD virtual na próxima inicialização. Guardar resultados TEMP dentro
do guest até exportação controlada offline; nunca publicar o disco Windows.

No PowerShell elevado do convidado, fontes copiadas para diretório temporário:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\legacy-validation.ps1
```

O teste se recusa a atribuir prova legado ao PS5/7. Exigir o arquivo PASS.txt
e os logs/ambiente completos; exit0 sozinho nunca é comprovação no PS2. Captura casos reais de
processos/ACLs e modelo de orquestração. Depois, instalar o EXE candidato,
verificar fila/driver/porta, executar `Install-Queue-Win7.cmd capture-test`,
reinstalar, desinstalar e reinstalar nos snapshots próprios. Inspecionar acentos
nas telas, logs e Notepad pt-BR. Não usar testes de rejeição OS do CI no Win7,
pois nesse alvo o instalador realmente provisionaria recursos.

Sem CorelDRAW licenciado e hardware, isso ainda não valida impressão Corel nem
corte. Nenhum serial/dispositivo físico deve ser conectado ao laboratório.

Referências: [QEMU invocation](https://qemu.readthedocs.io/en/v8.2.10/system/invocation.html),
[monitor/ACPI](https://www.qemu.org/docs/master/system/monitor.html).
