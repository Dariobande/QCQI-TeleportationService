# QCQI - Quantum Teleportation Service: Network & Circuit-Level Simulation

[![Julia](https://img.shields.io/badge/Language-Julia%201.9+-9558B2.svg)](https://julialang.org/)
[![Python](https://img.shields.io/badge/Language-Python%203.9+-3776AB.svg)](https://www.python.org/)
[![QuantumSavory](https://img.shields.io/badge/Framework-QuantumSavory.jl-009688.svg)](https://github.com/QuantumSavory/QuantumSavory.jl)
[![Qiskit Aer](https://img.shields.io/badge/Simulator-Qiskit%20Aer-6929C4.svg)](https://qiskit.org/)

[Specifications](Specifications.pdf) | [Presentation](Presentation.pdf) | [Julia Simulation](Julia/) | [Python Simulation](Python/) | [Simulation Results](results/)

This repository contains the design, dual-paradigm simulation, and fidelity verification of a **Quantum Teleportation Service** across noisy quantum networks, comparing asynchronous discrete-event network protocols with gate-level quantum circuit simulations under parameterized depolarizing noise channels.

The project was developed for the **Quantum Computing and Quantum Internet** course (Master of Science in Computer Engineering, **Università di Pisa**) by **Dario Bandecchi** and **Giacomo Raffo**.

---

## Project Overview

Quantum teleportation is a foundational protocol in quantum communication enabling the transmission of an arbitrary unknown qubit state $|\psi\rangle = \alpha |0\rangle + \beta |1\rangle$ between two distant nodes (Sender and Receiver) using a shared pre-distributed entangled pair and two bits of classical communication.

In physical quantum networks, imperfect entanglement generation and noisy transmission lines degrade the quality of the shared EPR pair $|\Phi^+\rangle = \frac{1}{\sqrt{2}} (|00\rangle + |11\rangle)$. This project models this physical degradation using an isotropic depolarizing noise channel with probability $p_w \in [0.0, 1.0]$:

$$\rho_{\text{depol}} = (1 - p_w) |\Phi^+\rangle\langle\Phi^+| + p_w \frac{I}{4}$$

The degraded Bell state is subsequently consumed by the teleportation protocol, and the output state $\rho_{\text{out}}$ recovered at the receiver is evaluated against the ideal input state $\rho_{\text{in}} = |\psi\rangle\langle\psi|$ using quantum state fidelity:

$$F(\rho_{\text{in}}, \rho_{\text{out}}) = \text{Tr}\left(\sqrt{\sqrt{\rho_{\text{in}}} \rho_{\text{out}} \sqrt{\rho_{\text{in}}}}\right)$$

Key system properties and simulation features include:
- **Dual Simulation Paradigms:** Direct cross-validation between asynchronous discrete-event network modeling (Julia / `QuantumSavory.jl`) and gate-level density matrix circuit execution (Python / `Qiskit Aer`).
- **Asynchronous Protocol Architecture:** Realistic modeling of distributed quantum nodes using coroutines (`@process`, `@resumable`), asynchronous message queues, and queryable memory tags.
- **Stochastic Delays & Latencies:** Explicit modeling of physical network timings, including exponential setup times for entanglement distribution ($\mu = 200\text{ ms}$) and classical transmission propagation delays ($t_{\text{delay}} = 20\text{ ms}$).
- **Dynamic Circuit Corrections:** Implementation of conditional feed-forward Pauli corrections using real-time classical control flow (`if_test` in Qiskit, tag queries in QuantumSavory).
- **Exact Tomography & Fidelity Benchmarking:** Sweep over the full noise spectrum $p_w \in [0.0, 1.0]$ demonstrating perfect analytical and numerical consistency from ideal fidelity ($F = 1.00$) down to the theoretical completely depolarized limit ($F = 0.50$).

---

## Specifications & Simulation Parameters

The simulation parameters configure the network topology, physical link characteristics, and input quantum states:

| Parameter | Symbol | Default Value | Dimension / Type | Description |
| :--- | :---: | :---: | :---: | :--- |
| **Network Size** | $N$ | `10` | Nodes | Total number of quantum network nodes in the fully connected topology |
| **Noise Sweep Range** | $p_w$ | `0.0:0.05:1.0` | Probability | Depolarization probability parameter for Bell pair noise injection |
| **Trials per Noise Level** | $n_{\text{req}}$ | `1` (Julia) / `3` (Python) | Integer | Teleportation requests simulated between random node pairs per noise step |
| **Entanglement Setup Time** | $\mu_{\text{ent}}$ | `200.0` | Milliseconds (ms) | Mean of exponential distribution for asynchronous Bell pair generation |
| **Classical Link Delay** | $t_{\text{delay}}$ | `20.0` | Milliseconds (ms) | Latency of the classical communication channel between Sender and Receiver |
| **Teleported State** | $\vert\psi\rangle$ | $\frac{1}{\sqrt{2}}\vert 0\rangle + \frac{1}{\sqrt{2}}\vert 1\rangle$ | Statevector | Equal superposition arbitrary target state to be teleported |

### Protocol Correction Table

Upon performing Bell State Measurement (BSM) on the input state and the local half of the entangled pair, the sender generates two classical bits that dictate the conditional Pauli unitary operation applied by the receiver:

| Measurement Outcome | Receiver Pauli Correction | Receiver State Prior to Correction | Final Reconstructed State |
| :---: | :---: | :---: | :---: |
| `(0, 0)` | $I$ (Identity) | $\alpha\vert 0\rangle + \beta\vert 1\rangle$ | $\vert\psi\rangle$ |
| `(0, 1)` | $X$ (Bit Flip) | $\alpha\vert 1\rangle + \beta\vert 0\rangle$ | $\vert\psi\rangle$ |
| `(1, 0)` | $Z$ (Phase Flip) | $\alpha\vert 0\rangle - \beta\vert 1\rangle$ | $\vert\psi\rangle$ |
| `(1, 1)` | $X Z$ (Bit and Phase Flip) | $\alpha\vert 1\rangle - \beta\vert 0\rangle$ | $\vert\psi\rangle$ |

---

## Architecture & Simulation Details

The project is structured into two autonomous simulation engines, each capturing distinct abstraction layers of quantum systems:

1. **Discrete-Event Quantum Network Engine ([`Julia/TeleportationService.jl`](file:///Users/dariobandecchi/Documents/GitHub/teleportation-service/Julia/TeleportationService.jl)):**
   - **`QNCoreProtocol`:** Emulates the physical quantum network substrate. Schedules entangled pair generation with exponentially distributed delays, injects depolarizing noise into the bipartite density matrix, and tags receiver/sender registers with creation timestamps.
   - **`SenderProtocol`:** Initializes the target quantum state, synchronizes via `@yield onchange_tag(regSrc)`, executes the Bell measurement (`CNOT` followed by `Hadamard` and projective readout), and transmits classical results over the network channel.
   - **`ReceiverProtocol`:** Suspends on local registers waiting for entanglement establishment and classical message arrival via asynchronous message buffer (`mb = messagebuffer(net, nodeDst)`), extracting measurement tags and applying conditional Pauli $Z$ and $X$ transformations.

2. **Gate-Level Quantum Circuit Engine ([`Python/teleportation_service.ipynb`](file:///Users/dariobandecchi/Documents/GitHub/teleportation-service/Python/teleportation_service.ipynb)):**
   - **Circuit Construction (`create_teleportation_circuit`):** Allocates quantum registers across $N$ nodes (2 qubits per node: message qubit and entangled carrier qubit) and 2 classical registers for BSM readout.
   - **Custom Noise Model Injection:** Applies a 2-qubit depolarizing error channel (`depolarizing_error(pw, 2)`) targeted specifically to the entangling `CX` gate during Bell state preparation.
   - **Dynamic Mid-Circuit Execution:** Employs Qiskit's `with teleportation_circuit.if_test((c, 1))` constructs to implement real-time feed-forward unitary corrections without terminating circuit evaluation.
   - **Tomography & Aer Simulation:** Runs `AerSimulator(method='density_matrix')` saving Bob's single-qubit density matrix (`save_density_matrix`), followed by exact fidelity calculation via `state_fidelity`.

---

## Repository Structure

```
.
├── Julia/
│   └── TeleportationService.jl       # Discrete-event network simulation script
├── Python/
│   └── teleportation_service.ipynb   # Gate-level circuit simulation notebook
├── results/                          # Benchmarking plots and simulation artifacts
│   ├── plot_julia.png                # Fidelity vs. noise plot from QuantumSavory
│   └── plot_qiskit.png               # Fidelity vs. noise plot from Qiskit Aer
├── Presentation.pdf                  # Project presentation
├── Specifications.pdf                # Project specifications
└── README.md                         # Project documentation
```

> **Note on simulation outputs:**  
> Numerical execution plots generated by the simulations are stored in the [`results/`](file:///Users/dariobandecchi/Documents/GitHub/teleportation-service/results/) directory.

---

## Setup & Execution Guide

### Prerequisites & Dependencies

#### Julia Environment
- **Julia 1.9+**
- Required Julia packages:
  ```julia
  QuantumSavory, ConcurrentSim, ResumableFunctions, Graphs, Distributions, Plots, Plots.Measures
  ```

#### Python Environment
- **Python 3.9+**
- Required Python libraries:
  ```bash
  pip install qiskit qiskit-aer numpy matplotlib jupyter
  ```

---

### Running the Julia Simulation

1. **Navigate to the Julia Directory:**
   ```bash
   cd Julia
   ```

2. **Install Required Packages (if not already installed):**
   ```bash
   julia -e 'using Pkg; Pkg.add(["QuantumSavory", "ConcurrentSim", "ResumableFunctions", "Graphs", "Distributions", "Plots"])'
   ```

3. **Execute the Simulation Script:**
   ```bash
   julia TeleportationService.jl
   ```
   The script logs step-by-step protocol events (pair creation, measurement, classical transmission, Pauli corrections) and outputs the fidelity plot.

---

### Running the Python / Qiskit Notebook

1. **Navigate to the Python Directory:**
   ```bash
   cd Python
   ```

2. **Launch Jupyter Notebook:**
   ```bash
   jupyter notebook teleportation_service.ipynb
   ```

3. **Run All Cells:**  
   Execute the cells sequentially to visualize the dynamic quantum teleportation circuit with feed-forward corrections, run the density matrix simulator across $p_w \in [0.0, 1.0]$, and generate the fidelity plot.

---

## Simulation Results & Comparative Analysis

Quantum state fidelity $F(\rho_{\text{in}}, \rho_{\text{out}}) = \text{Tr}\left(\sqrt{\sqrt{\rho_{\text{in}}} \rho_{\text{out}} \sqrt{\rho_{\text{in}}}}\right)$ was systematically evaluated across depolarization probabilities $p_w \in [0.0, 1.0]$ between random pairs of network nodes.

### Key Observations
- **Perfect Protocol Parity:** Both the discrete-event network simulation (Julia / `QuantumSavory.jl`) and the gate-level quantum circuit (Python / `Qiskit Aer`) produce mathematically equivalent fidelity decay curves across the entire noise spectrum.
- **Ideal Regime ($p_w = 0.0$):** Under noiseless conditions, the teleportation protocol achieves perfect state reconstruction fidelity ($F = 1$).
- **Convergence to Maximally Mixed State ($p_w = 1.0$):** At maximal noise ($p_w = 1.0$), the output state collapses to the maximally mixed state $\rho_{\text{out}} = \frac{I}{2}$, yielding the theoretical baseline fidelity of $\langle\psi|\frac{I}{2}|\psi\rangle = 0.5$.

The generated benchmarking plots are available in:
- [`results/plot_julia.png`](file:///Users/dariobandecchi/Documents/GitHub/teleportation-service/results/plot_julia.png)
- [`results/plot_qiskit.png`](file:///Users/dariobandecchi/Documents/GitHub/teleportation-service/results/plot_qiskit.png)

---

## Authors & Academic Context

- **Course:** Quantum Computing and Quantum Internet
- **Degree:** Master of Science in Computer Engineering
- **Institution:** Università di Pisa
- **Authors:**
  - Dario Bandecchi
  - Giacomo Raffo
