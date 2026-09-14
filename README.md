# Quantum Teleportation Service: Network & Circuit-Level Simulation

[![Julia](https://img.shields.io/badge/Julia-1.9+-9558B2?style=flat&logo=julia&logoColor=white)](https://julialang.org/)
[![Qiskit](https://img.shields.io/badge/Qiskit-1.0+-6929C4?style=flat&logo=qiskit&logoColor=white)](https://qiskit.org/)
[![QuantumSavory](https://img.shields.io/badge/QuantumSavory-NetworkSim-009688?style=flat)](https://github.com/QuantumSavory/QuantumSavory.jl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A dual-paradigm simulation framework for **Quantum Teleportation** protocols in noisy quantum networks, developed as part of the **Quantum Computing and Quantum Internet** course by **Dario Bandecchi** and **Giacomo Raffo**.

This project compares **discrete-event quantum network simulations** (in Julia using `QuantumSavory.jl` and `ConcurrentSim.jl`) with **gate-level quantum circuit simulations** (in Python using `Qiskit Aer`), benchmarking quantum state fidelity decay across parameterized depolarizing noise channels ($p_w \in [0.0, 1.0]$).

---

## 🛠️ Technical Overview & Architecture

This repository implements quantum teleportation across two complementary simulation levels:

### 1. Event-Driven Quantum Network Simulation (Julia / QuantumSavory)
* **Frameworks**: `QuantumSavory.jl`, `ConcurrentSim.jl`, `ResumableFunctions.jl`, `Graphs.jl`.
* **Asynchronous Protocol Architecture**: Models distributed quantum node interactions as concurrent processes (`@process`, `@resumable` generators):
  * **`QNCoreProtocol`**: Simulates noisy Bell pair initialization over an $N$-node network with stochastic entanglement setup time (exponentially distributed, $\mu = 200\text{ ms}$).
  * **`SenderProtocol`**: Encapsulates initial quantum state injection, Bell state measurement (BSM), and classical message transmission over channels with realistic latency ($t_{\text{delay}} = 20\text{ ms}$).
  * **`ReceiverProtocol`**: Listens for classical measurement tags via asynchronous message buffers (`messagebuffer`), applying conditional Pauli corrections ($X, Z$).
* **Noise Model**: Applies depolarizing channels to initialized Bell states:
  $$\rho_{\text{depol}} = (1 - p_w) |\Phi^+\rangle\langle\Phi^+| + p_w \frac{I}{4}$$

### 2. Gate-Level Quantum Circuit Simulation (Python / Qiskit)
* **Frameworks**: `Qiskit`, `Qiskit Aer`, `NumPy`, `Matplotlib`.
* **Density Matrix Execution**: Utilizes `AerSimulator(method='density_matrix')` for exact quantum state tomography under noise.
* **Dynamic Logic**: Employs Qiskit's `if_test` runtime classical control flow to model real-time feed-forward Pauli corrections.
* **Custom Noise Injection**: Injects 2-qubit depolarizing error channels (`depolarizing_error(pw, 2)`) targeted specifically at entangling `CX` gates during Bell state generation.

---

## 📊 Key Results & Fidelity Analysis

Quantum State Fidelity $F(\rho_{\text{in}}, \rho_{\text{out}}) = \text{Tr}\left(\sqrt{\sqrt{\rho_{\text{in}}} \rho_{\text{out}} \sqrt{\rho_{\text{in}}}}\right)$ was systematically evaluated across depolarization probabilities $p_w \in [0.0, 1.0]$. 

Under ideal noiseless conditions ($p_w = 0$), both simulation paradigms achieve a perfect state fidelity of `1.00`. As the depolarizing probability reaches maximal noise ($p_w = 1.0$), the output converges to the maximally mixed state with a theoretical baseline fidelity of `0.25`.

The generated plots (`Results/plot_julia.png` and `Results/plot_qiskit.png`) validate complete numerical consistency between the asynchronous event-driven network protocol and the gate-level quantum circuit execution.

---

## 📂 Project Structure

```
teleportation-service/
├── Julia/
│   └── TeleportationService.jl     # Discrete-event network simulation protocol
├── Python/
│   └── teleportation_service.ipynb # Gate-level Qiskit noise simulation notebook
├── Results/
│   ├── plot_julia.png              
│   └── plot_qiskit.png
└── Specifications.pdf              # Project specifications
└── Presentation.pdf                # Presentation slides
└── README.md                       
```
---

## 🚀 Getting Started

### Prerequisites

* **Julia** $\ge 1.9$
* **Python** $\ge 3.9$ with `qiskit`, `qiskit-aer`, `numpy`, `matplotlib`, `jupyter`

### Running the Julia Simulation

```bash
# Clone the repository
git clone https://github.com/Dariobande/teleportation-service.git
cd teleportation-service/Julia

# Run the Julia simulation script
julia TeleportationService.jl
```

### Running the Python / Qiskit Notebook

```bash
cd teleportation-service/Python
jupyter notebook teleportation_service.ipynb
```
---

## 👥 Authors & Academic Context

* **Course**: Quantum Computing and Quantum Internet
* **Authors**: Dario Bandecchi, Giacomo Raffo

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for details.
