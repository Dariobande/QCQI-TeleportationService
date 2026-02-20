using QuantumSavory
using ConcurrentSim
using ResumableFunctions
using Graphs
using Distributions
using Plots
using Plots.Measures

# PARAMETERS FOR THE SIMULATION:
# Number of nodes in the network
N = 10
# Noise levels to simulate (probability of depolarization) -> from 0 (no noise) to 1 (completely depolarized) with steps of 0.05
pw = 0.0:0.05:1.0
# Number of teleportation requests to simulate per noise level
n_requests_per_pw = 1 
# Average time (in ms) to create an entangled pair
avg_entanglement_time = 200.0
# Classical communication delay (in ms)
classical_delay = 20.0
# Arbitrary input state to teleport
a = 1/sqrt(2)
b = 1/sqrt(2)
input_state = a * Z₁ + b * Z₂

# Define the Tag for the entangled qubits
struct EntangledTag
    time::Int64
end
Tag(tag::EntangledTag) = QuantumSavory.Tag(EntangledTag, tag.time)

# Define the Tag for the measurement results
struct MeasurementResultTag
    time::Int64
    result1::Int64
    result2::Int64
end
Tag(tag::MeasurementResultTag) = QuantumSavory.Tag(MeasurementResultTag, tag.time, tag.result1, tag.result2)

# Define the Quantum Network Core Protocol structure
@kwdef struct QNCoreProtocol <: QuantumSavory.ProtocolZoo.AbstractProtocol
    sim::Simulation
    net::RegisterNet
    nodeSrc::Int64
    nodeDst::Int64
    pw::Float64
end

# Define the Quantum Network Core Protocol behavior:
# This protocol creates a depolarized Bell pair between nodeSrc and nodeDst and tags the qubits with the time they were created
@resumable function (prot::QNCoreProtocol)()

    @info "Quantum Network Core starting up" 

    # Retrieve the protocol parameters
    sim, net, nodeSrc, nodeDst, pw = prot.sim, prot.net, prot.nodeSrc, prot.nodeDst, prot.pw

    # Create a depolarized Bell state with depolarization probability pw
    bell_state = (Z₁ ⊗ Z₁ + Z₂ ⊗ Z₂)/ √2
    bell_state_density_matrix = SProjector(bell_state)
    comp_mixed_state = MixedState(bell_state_density_matrix)

    depolarized_bell_state = (1 - pw) * bell_state_density_matrix + pw * comp_mixed_state

    # Retrieve the registers and slots for the sender and receiver
    regSrc = net[nodeSrc]  # Sender's register
    regDst = net[nodeDst]  # Receiver's register

    slotSrc = regSrc[2]    # Sender's second qubit slot
    slotDst = regDst[2]    # Receiver's second qubit slot

    # Exponentially distributed timeout to create the entangled pair
    @yield timeout(sim, rand(Exponential(avg_entanglement_time)))

    # Initialize the two slots with the depolarized Bell state
    initialize!((slotSrc, slotDst), depolarized_bell_state, time=now(sim))

    # Tag the qubits with the time they were created
    tag!(slotSrc, EntangledTag(round(Int64, now(sim))))
    tag!(slotDst, EntangledTag(round(Int64, now(sim))))

    @info "Entangled pair initialized correctly to state $(depolarized_bell_state) with pw = $pw between node $nodeSrc and node $nodeDst at time $(now(sim)) ms"
end

# Define the Sender Protocol structure
@kwdef struct SenderProtocol <: QuantumSavory.ProtocolZoo.AbstractProtocol
    sim::Simulation
    net::RegisterNet
    nodeSrc::Int64
    nodeDst::Int64
end

# Define the Sender Protocol behavior:
# This protocol waits for the entangled pair to be created, performs the Bell measurement on the
#  input state and the sender's qubit of the entangled pair, and sends the measurement results to the receiver
@resumable function (prot::SenderProtocol)()

    # Retrieve the protocol parameters
    sim, net, nodeDst, nodeSrc = prot.sim, prot.net, prot.nodeDst, prot.nodeSrc

    @info "Sender (node $(nodeSrc)) starting up: the state to teleport is $(input_state)" 

    # Retrieve the sender's register and the relevant slots
    regSrc = net[nodeSrc]  # Sender's register

    slot_rho = regSrc[1]   # Slot for the input state to teleport
    slot_bell = regSrc[2]  # Slot for the qubit in the entangled pair

    # Initialize the input state to teleport
    initialize!(slot_rho, input_state, time=now(sim))

    # Wait for the entangled pair to be created and tagged
    @yield onchange_tag(regSrc)

    @info "Sender received message that QN Core initialized entangled qubit (current time: $(now(sim)))"

    # Perform the Bell measurement on the input state and the qubit in the entangled pair
    apply!((slot_rho, slot_bell), CNOT)
    apply!(slot_rho, H)

    basis = [Z₁, Z₂]
    result1 = project_traceout!(regSrc, 1, basis)
    result2 = project_traceout!(regSrc, 2, basis)

    # Get the channel from Sender to Receiver and send the measurement results
    chan = channel(net, nodeSrc => nodeDst)
    put!(chan, MeasurementResultTag(round(Int64, now(sim)), result1, result2)) 
end

# Define the Receiver Protocol structure
@kwdef struct ReceiverProtocol <: QuantumSavory.ProtocolZoo.AbstractProtocol
    sim::Simulation
    net::RegisterNet
    nodeDst::Int64
end

# Define the Receiver Protocol behavior:
# This protocol waits for the entangled pair to be created, receives the measurement results from the sender
#  and applies the appropriate corrections to the receiver's qubit of the entangled pair based on the measurement results
@resumable function (prot::ReceiverProtocol)()

    # Retrieve the protocol parameters
    sim, net, nodeDst = prot.sim, prot.net, prot.nodeDst

    @info "Receiver (node $(nodeDst)) starting up" 

    # Retrieve the receiver's register and the relevant slot
    regDst = net[nodeDst]  # Receiver's register
    slot_bell = regDst[2]  # Slot for the qubit in the entangled pair

    # Wait for the entangled pair to be created and tagged
    @yield onchange_tag(regDst)

    @info "Receiver received message that QN Core initialized entangled qubit (current time: $(now(sim)))"

    # Wait for the measurement results from the sender
    mb = messagebuffer(net, nodeDst)
    @yield wait(mb)

    @info "Receiver received measurement results from the sender (current time: $(now(sim)))"

    # Extract the measurement results from the tag in the message buffer
    results = query(mb, MeasurementResultTag, ❓, ❓, ❓)
    tag = results.tag
    result1, result2 = tag[3], tag[4]

    # Apply the appropriate correction based on the measurement results
    if result1 == 2
        apply!(slot_bell, Z)
    end
    if result2 == 2
        apply!(slot_bell, X)
    end

    # Extract the output state from the receiver's slot after applying the corrections
    output_state = net[nodeDst].staterefs[2].state

    @info "Receiver applied the final corrections: received state is $(output_state)"
end

avg_fidelities = Float64[]

# Network Simulation Loop:
# For each noise level, we simulate multiple teleportation requests between randomly selected sender and receiver nodes,
#  compute the fidelity of the teleported state, and then average the fidelities for that noise level
for p in pw
    current_pw_fidelities = Float64[]

    for i in 1:n_requests_per_pw

        # Create a fully-connected network with N nodes and 2 slots per node (one for the input state and one for the entangled qubit)
        regs = [Register(2) for _ in 1:N]
        graph = complete_graph(N)
        net = RegisterNet(graph, regs, classical_delay=classical_delay)
        
        # Get the time tracker for the simulation
        sim = get_time_tracker(net)

        # Randomly select source and destination nodes
        src, dst = sample(1:N, 2, replace=false)  

        # Run the processes
        QNCoreProt = QNCoreProtocol(sim=sim, net=net, nodeSrc=src, nodeDst=dst, pw=p)
        @process QNCoreProt()
        ReceiverProt = ReceiverProtocol(sim=sim, net=net, nodeDst=dst)
        @process ReceiverProt()
        SenderProt = SenderProtocol(sim=sim, net=net, nodeSrc=src, nodeDst=dst)
        @process SenderProt()

        # Run the simulation until all events are processed
        run(sim)

        # Density matrix representation of the input state
        rho_in = SProjector((input_state))

        # Compute the fidelity and push it to the list of fidelities for the current noise level
        fidelity = observable([net[dst]], [2], rho_in)
        push!(current_pw_fidelities, fidelity)
    end

    # Compute the average fidelity for the current noise level and push it to the list of average fidelities
    avg_fidelity = mean(current_pw_fidelities)
    push!(avg_fidelities, avg_fidelity)
end

# Plot the average fidelity as a function of the noise level
plot(pw, avg_fidelities, 
     title="\nTeleportation Fidelity as a function of the Depolarizion Probability",
     titlefontsize=11,
     titlelocation=:center,     
     xlabel="Depolarization Probability (pw)",
     ylabel="Average Fidelity \$F(\\rho, \\rho')\$", 
     guidefontsize=8,
     tickfontsize=7,
     margin=5mm,
     marker=:circle, 
     markersize=4,
     linewidth=1.5, 
     label="Fidelity",
     grid=true,
     ylims=(0, 1.1),
     legendfontsize=7,
     dpi=300,
     size=(800,500))