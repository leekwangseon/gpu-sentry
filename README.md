# rackprobe

`rackprobe`는 NVIDIA GPU 서버를 현장에서 진단하기 위한 로컬 및 SSH 기반 도구입니다.
서버 하드웨어를 자동으로 탐지하고, GPU 구성에 맞는 스트레스 테스트를 생성하며,
원본 로그 수집과 장애 징후 분석을 수행한 뒤 고객 제출용 HTML 및 PDF 보고서를 만듭니다.

이 프로젝트는 기존 `gpu_remote_test_from_master_v4.sh`의 기능을 유지하면서
확장성과 유지보수성을 높일 수 있도록 모듈 구조로 리팩터링한 결과물입니다.
RHEL 8, Rocky Linux 8/9, AlmaLinux, Ubuntu 22.04/24.04와 Dell, ASUS,
Lenovo, Supermicro 및 표준 기반 GPU 서버를 대상으로 설계되었습니다.

## 주요 기능

- GPU 개수와 모델, 드라이버 및 CUDA 버전, Compute Capability, PCIe 링크 상태,
  GPU 토폴로지, NUMA, CPU, 메모리, BIOS 및 서버 제조사를 자동으로 탐지합니다.
- RTX 3090/4090, A100, H100, H200, L40/L40S, RTX PRO Blackwell 계열을
  지원하며 모델별 허용 목록을 사용하지 않아 향후 NVIDIA GPU도 쉽게 지원할 수 있습니다.
- 모든 시스템에서 GPU별 Single 및 Pair 테스트를 생성하고, GPU가 8개 이상이면
  Half 테스트를 추가하며 전체 GPU를 사용하는 All 테스트도 자동으로 생성합니다.
- PATH에 등록된 CUDA와 환경 모듈(`module`)로 제공되는 CUDA를 모두 탐지합니다.
- gpu-burn이 없으면 `git → curl → wget → 내장 오프라인 압축 파일` 순서로
  소스 코드를 확보하여 자동으로 빌드하고 설치합니다.
- GPU 온도, 소비 전력, GPU/메모리 사용률 등의 텔레메트리와 커널 로그를 수집합니다.
- NVIDIA Xid 48/79, PCIe AER, MCE, NMI 및 스트레스 테스트 실패를 자동 분석합니다.
- Dell racadm/OMSA, Lenovo OneCLI 또는 범용 ipmitool을 사용할 수 있을 때
  제조사별 하드웨어 정보를 추가로 수집합니다.

## 빠른 시작

```bash
git clone https://github.com/leekwangseon/rackprobe.git
cd rackprobe
chmod +x bin/rackprobe

# 로컬 서버 진단
sudo ./bin/rackprobe --local --power 300 --time 600

# SSH 원격 서버 진단
./bin/rackprobe --host gpu01 --power 300 --time 600
```

gpu-burn을 설치하거나 스트레스 테스트를 실행하지 않고 하드웨어 정보만 안전하게
수집하려면 다음과 같이 실행합니다.

```bash
./bin/rackprobe --host gpu01 --inventory-only
```

## 실행 옵션

전체 옵션은 다음 명령으로 확인할 수 있습니다.

```bash
./bin/rackprobe --help
```

주요 옵션은 다음과 같습니다.

| 옵션 | 설명 | 기본값 |
| --- | --- | --- |
| `--local` | 현재 서버를 직접 진단합니다. | - |
| `--host HOST` | 지정한 서버를 SSH로 진단합니다. | - |
| `--power WATTS` | 테스트 중 적용할 NVIDIA GPU 전력 제한입니다. | 변경하지 않음 |
| `--time SECONDS` | 각 스트레스 테스트의 실행 시간입니다. | 300초 |
| `--cooldown SECONDS` | 테스트 사이의 냉각 대기 시간입니다. | 60초 |
| `--interval SECONDS` | GPU 텔레메트리 수집 간격입니다. | 2초 |
| `--output DIRECTORY` | 로그를 저장할 최상위 디렉터리입니다. | `./logs` |
| `--gpu-burn PATH` | 사용할 gpu-burn 실행 파일 경로입니다. | `/opt/gpu-burn/gpu_burn` |
| `--continue-on-failure` | 테스트 하나가 실패해도 나머지 테스트를 계속합니다. | 즉시 중단 |
| `--inventory-only` | 설치와 스트레스 테스트를 생략하고 정보만 수집합니다. | 비활성화 |

`--power`에 0보다 큰 값을 지정하면 스트레스 테스트 전에 `nvidia-smi -pl`로
모든 GPU에 전력 제한을 적용합니다. 프로그램 종료 시에는 수집해 둔 원래 전력 제한으로
복원합니다. 전력 제한 변경에는 일반적으로 관리자 권한이 필요합니다.

## 로그와 보고서

진단 결과는 다음 구조로 자동 저장됩니다.

```text
logs/
└── YYYYMMDD/
    └── HOST/
        ├── main.log
        ├── gpu.csv
        ├── dmesg.log
        ├── gpu-inventory.csv
        ├── pcie-topology.log
        ├── hardware.tsv
        ├── vendor.log
        ├── test-plan.tsv
        ├── results.tsv
        ├── analysis.tsv
        ├── report.html
        └── report.pdf
```

원본 로그와 자동 분석 결과를 함께 보존하므로 엔지니어가 보고서의 결론을 직접
검증할 수 있습니다. HTML 보고서에는 GPU, Driver, CUDA, BIOS, 최고/평균 온도,
최대 전력, PCIe 상태, GPU/메모리 사용률 및 최종 PASS/FAIL 결과가 포함됩니다.

## 오프라인 환경

인터넷이 차단된 환경에서는 검토를 마친 upstream gpu-burn 소스 압축 파일을
다음 위치에 배치합니다.

```text
tools/gpu-burn/gpu-burn.tar.gz
```

git, curl 및 wget을 통한 다운로드가 모두 실패하면 이 압축 파일을 대상 서버로
복사하여 사용합니다. 대상 서버에는 CUDA, C++ 컴파일러, make 및 tar가 미리
설치되어 있어야 합니다.

## 제조사별 정보 수집

- Dell: `racadm` 또는 OMSA의 `omreport`
- Lenovo: `OneCLI`
- Supermicro 및 기타 IPMI 서버: `ipmitool`
- ASUS 및 기타 서버: 표준 DMI, NVIDIA, PCIe 및 IPMI 인터페이스

관련 도구가 설치되어 있지 않아도 기본 GPU 진단은 계속 진행되며, 사용할 수 없는
제조사 수집기는 `vendor.log`에 안내 메시지를 기록합니다. rackprobe는 BIOS나 BMC
설정을 변경하지 않습니다.

## 안전 주의사항

GPU 스트레스 테스트는 냉각, 전원 또는 하드웨어가 불안정한 서버에서 장애를
표면화할 수 있으며 운영 중인 워크로드에 영향을 줄 수 있습니다.

실행하기 전에 다음 사항을 확인하십시오.

1. 서버의 운영 워크로드를 중지하거나 다른 노드로 이동합니다.
2. 승인된 유지보수 시간을 확보합니다.
3. 서버의 전원 용량과 냉각 상태를 확인합니다.
4. GPU 및 서버 제조사가 허용하는 전력·온도 범위를 확인합니다.
5. 첫 실행은 `--inventory-only`로 권한과 수집 결과를 점검합니다.

rackprobe는 진단 정보를 읽고 필요할 때 gpu-burn을 설치하지만, 펌웨어 업데이트나
BIOS/BMC 설정 변경은 수행하지 않습니다. 자동 분석 결과는 엔지니어의 판단을
보조하기 위한 것으로 제조사 공식 진단을 대체하지 않습니다.

## 개발 및 검증

```bash
make lint
make test
```

모든 Shell 스크립트는 Bash strict mode와 ShellCheck 경고 0개를 기준으로 관리합니다.
자세한 설계는 [아키텍처 문서](docs/architecture.md), 문제 해결 방법은
[트러블슈팅 문서](docs/troubleshooting.md), 기여 방법은
[CONTRIBUTING.md](CONTRIBUTING.md)를 참고하십시오.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포됩니다.
