# GPU Sentry

`gpu-sentry`는 NVIDIA GPU 서버를 현장에서 진단하기 위한 로컬 및 SSH 기반 도구입니다.
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
- `CUDA_HOME`/`CUDA_PATH`, PATH, 표준 설치 경로, NVIDIA HPC SDK, 환경 모듈,
  제한된 파일시스템 검색을 통해 CUDA Toolkit의 실제 경로를 자동 탐지합니다.
- gpu-burn이 없으면 `git → curl → wget → 내장 오프라인 압축 파일` 순서로
  소스 코드를 확보하여 자동으로 빌드하고 설치합니다.
- GPU 온도, 소비 전력, GPU/메모리 사용률 등의 텔레메트리와 커널 로그를 수집합니다.
- NVIDIA Xid 48/79, PCIe AER, MCE, NMI 및 스트레스 테스트 실패를 자동 분석합니다.
- Dell racadm/OMSA, Lenovo OneCLI 또는 범용 ipmitool을 사용할 수 있을 때
  제조사별 하드웨어 정보를 추가로 수집합니다.
- 목적에 맞는 `inventory`, `quick`, `standard`, `burn-in`, `rma` 프로파일과
  실행 전 안전 검사를 제공합니다.
- DCGM이 설치된 서버에서는 공식 NVIDIA 진단을 자동으로 추가 실행하고,
  자동화에 사용할 수 있는 `report.json`을 생성합니다.

## 빠른 시작

```bash
git clone https://github.com/leekwangseon/gpu-sentry.git
cd gpu-sentry
chmod +x bin/gpu-sentry

# 로컬 서버 진단
sudo ./bin/gpu-sentry --local --power 300 --time 600

# SSH 원격 서버 진단
./bin/gpu-sentry --host gpu01 --power 300 --time 600
```

gpu-burn을 설치하거나 스트레스 테스트를 실행하지 않고 하드웨어 정보만 안전하게
수집하려면 다음과 같이 실행합니다.

```bash
./bin/gpu-sentry --host gpu01 --inventory-only
```

## 실행 옵션

전체 옵션은 다음 명령으로 확인할 수 있습니다.

```bash
./bin/gpu-sentry --help
```

주요 옵션은 다음과 같습니다.

| 옵션 | 설명 | 기본값 |
| --- | --- | --- |
| `--local` | 현재 서버를 직접 진단합니다. | - |
| `--host HOST` | 지정한 서버를 SSH로 진단합니다. | - |
| `--profile NAME` | `inventory`, `quick`, `standard`, `burn-in`, `rma` 중 하나를 선택합니다. | `standard` |
| `--power WATTS` | 테스트 중 적용할 NVIDIA GPU 전력 제한입니다. | 변경하지 않음 |
| `--time SECONDS` | 각 스트레스 테스트의 실행 시간입니다. | 300초 |
| `--cooldown SECONDS` | 테스트 사이의 냉각 대기 시간입니다. | 60초 |
| `--interval SECONDS` | GPU 텔레메트리 수집 간격입니다. | 2초 |
| `--output DIRECTORY` | 로그를 저장할 최상위 디렉터리입니다. | `./logs` |
| `--cuda-home DIRECTORY` | 대상 서버에서 사용할 CUDA Toolkit 루트를 직접 지정합니다. | 자동 탐지 |
| `--gpu-burn PATH` | 사용할 gpu-burn 실행 파일 경로입니다. | `/opt/gpu-burn/gpu_burn` |
| `--max-start-temp C` | 이 온도 이상인 GPU가 있으면 부하 테스트를 차단합니다. | 80°C |
| `--min-free-mb MiB` | 로그 저장소에 필요한 최소 여유 공간입니다. | 500 MiB |
| `--force` | 안전 검사 실패를 확인하고 강제로 계속합니다. | 비활성화 |
| `--continue-on-failure` | 테스트 하나가 실패해도 나머지 테스트를 계속합니다. | 즉시 중단 |
| `--inventory-only` | 설치와 스트레스 테스트를 생략하고 정보만 수집합니다. | 비활성화 |

`--power`에 0보다 큰 값을 지정하면 스트레스 테스트 전에 `nvidia-smi -pl`로
모든 GPU에 전력 제한을 적용합니다. 프로그램 종료 시에는 수집해 둔 원래 전력 제한으로
복원합니다. 전력 제한 변경에는 일반적으로 관리자 권한이 필요합니다.

## 진단 프로파일과 안전 검사

- `inventory`: 부하 없이 인벤토리와 로그만 수집합니다.
- `quick`: 전체 GPU를 대상으로 60초 빠른 점검과 DCGM Level 1을 수행합니다.
- `standard`: GPU별·Pair·Half·All 계획과 DCGM Level 1을 수행합니다.
- `burn-in`: 장시간 부하와 DCGM Level 2를 수행합니다.
- `rma`: 제조사 제출용 장시간 점검과 DCGM Level 3을 수행합니다.

부하 테스트 전에는 활성 GPU 프로세스, GPU 시작 온도, MIG 모드, 전력 제한 범위,
Slurm 작업 할당 및 로컬 로그 공간을 확인합니다. 차단 조건이 발견되면 보고서를
남기고 종료 코드 7로 중단합니다. `--force`는 위험을 검토한 경우에만 사용하십시오.

DCGM이 없거나 해당 GPU에서 지원되지 않으면 기존 `nvidia-smi`와 gpu-burn 경로를
계속 사용합니다. GeForce GPU에서는 DCGM 진단을 지원 범위인 Level 1로 제한합니다.

## CUDA Toolkit 탐지

GPU Sentry는 `/usr/local/cuda`를 고정값으로 사용하지 않습니다. 다음 순서로
대상 서버의 CUDA Toolkit을 찾고 `nvcc`의 심볼릭 링크를 해석하여 실제 루트
경로를 gpu-burn 빌드에 전달합니다.

1. `--cuda-home`으로 지정한 경로
2. 대상 환경의 `CUDA_HOME` 또는 `CUDA_PATH`
3. PATH에서 발견한 `nvcc`
4. `/usr/local/cuda*`, `/opt/cuda*`, NVIDIA HPC SDK CUDA 경로
5. Environment Modules 또는 Lmod에서 발견한 CUDA 모듈(높은 버전 우선)
6. `/usr/local`, `/opt`, `/apps`, `/software` 아래의 제한된 깊이 검색

자동 탐지가 어려운 사내 모듈명이나 사용자 정의 설치 경로는 다음처럼 명시할 수
있습니다. SSH 모드에서는 이 경로가 로컬 PC가 아니라 대상 서버의 경로입니다.

```bash
./bin/gpu-sentry --host gpu01 --cuda-home /apps/nvidia/cuda/12.4 --time 600
```

유효한 Toolkit은 `bin/nvcc`와 `include/cuda.h`가 모두 존재해야 합니다. 탐지된
CUDA 버전, 루트 경로 및 탐지 방식은 실행 로그와 HTML 보고서에 기록됩니다.

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
        ├── preflight.tsv
        ├── dcgm.log
        ├── dcgm.json
        ├── report.json
        ├── report.html
        └── report.pdf
```

원본 로그와 자동 분석 결과를 함께 보존하므로 엔지니어가 보고서의 결론을 직접
검증할 수 있습니다. HTML 보고서에는 GPU, Driver, CUDA, BIOS, 최고/평균 온도,
최대 전력, PCIe 상태, GPU/메모리 사용률 및 최종 PASS/FAIL 결과가 포함됩니다.
동일한 결과는 스키마 버전이 포함된 `report.json`으로도 생성됩니다.

## 종료 코드

| 코드 | 의미 |
| --- | --- |
| 0 | 진단 통과 |
| 1 | 일반 실행 오류 |
| 2 | 옵션 또는 프로파일 오류 |
| 3 | SSH 연결 오류 |
| 4 | 필수 도구 또는 빌드 의존성 오류 |
| 5 | GPU/DCGM 진단 실패 |
| 7 | 안전 사전검사에 의해 부하 테스트 차단 |

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
제조사 수집기는 `vendor.log`에 안내 메시지를 기록합니다. gpu-sentry는 BIOS나 BMC
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

gpu-sentry는 진단 정보를 읽고 필요할 때 gpu-burn을 설치하지만, 펌웨어 업데이트나
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
