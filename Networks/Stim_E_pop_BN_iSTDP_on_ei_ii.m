%% Simulation of a balanced network with I->E and I->I plasticity with External input to a subpop of E neurons.
%%% We would like to show that iSTDP is robust to perturbations in the
%%% input and that it maintains detailed balance in the network, as
%%% predicted by the thoery.

clear
%rng(1);

% Number of neurons in each population
N = 10000;
Ne1=0.4*N;
Ne2=0.4*N;
Ne=Ne1+Ne2;
Ni=0.2*N;

% Number of neurons in ffwd layer
Nx1=0.2*N;
Nx2=0.2*N;

% Recurrent net connection probabilities
P=0.1;

% Ffwd connection probs
Px=0.1;

%%%
% Correlation between the spike trains in the ffwd layer
c1=0.1;
c2=0.1;

% Timescale of correlation
taujitter=5;

Jei_initial = -250;

% Mean connection strengths between each cell type pair
Jm=[25 25 Jei_initial;25 25 Jei_initial; 112.5 112.5 -250]/sqrt(N);
Jxm=[180 180; 180 0; 135 0]/sqrt(N); % to turn off the layer X2 (stimulus), set the entry Jxm(1,2)=0.

% Time (in ms) for sim
T=300000;
T_start_stim = 100000;
T_end_stim = 200000;


% Time discretization
dt=.1;

% Proportions
qe1=Ne1/N;
qe2=Ne2/N;
qi=Ni/N;
qx1=Nx1/N;
qx2=Nx2/N;

% FFwd spike train rate (in kHz)
rx1=10/1000;
rx2=5/1000; % NOTE THIS.

% Number of time bins
Nt=round(T/dt);
time=dt:dt:T;

% Extra stimulus: Istim is a time-dependent stimulus
% it is delivered to all neurons with weights given by JIstim.
% Specifically, the stimulus to neuron j at time index i is:
% Istim(i)*JIstim(j)
Istim=zeros(size(time)); 
Istim(time>T/2)=0; 
jestim=0; 
jistim=0;
Jstim=sqrt(N)*zeros(N,1);%[jestim*ones(Ne,1); jistim*ones(Ni,1)]; 

% Build mean field matrices
Q=[qe1 qe2 qi; qe1 qe2 qi; qe1 qe2 qi];
Qf=[qx1 qx2; qx1 qx2; qx1 qx2];
W=P*(Jm*sqrt(N)).*Q;
Wx=Px*(Jxm*sqrt(N)).*Qf;

% Synaptic timescales
taux=10;
taue=8;
taui=4;

% Generate connectivity matrices
tic
J=[Jm(1,1)*binornd(1,P,Ne1,Ne1) Jm(1,2)*binornd(1,P,Ne1,Ne2) ...
   Jm(1,3)*binornd(1,P,Ne1,Ni);...
   Jm(2,1)*binornd(1,P,Ne2,Ne1) Jm(2,2)*binornd(1,P,Ne2,Ne2)...
   Jm(2,3)*binornd(1,P,Ne2,Ni);
   Jm(3,1)*binornd(1,P,Ni,Ne1) Jm(3,2)*binornd(1,P,Ni,Ne2) ...
   Jm(3,3)*binornd(1,P,Ni,Ni) ];
   
Jx=[Jxm(1,1)*binornd(1,Px,Ne1,Nx1) Jxm(1,2)*binornd(1,Px,Ne1,Nx2);...
    Jxm(2,1)*binornd(1,Px,Ne2,Nx1) Jxm(2,2)*binornd(1,Px,Ne2,Nx2);...
    Jxm(3,1)*binornd(1,Px,Ni,Nx1) Jxm(3,2)*binornd(1,Px,Ni,Nx2)];

tGen=toc;

disp(sprintf('\nTime to generate connections: %.2f sec',tGen))


%%% Make (correlated) Poisson spike times for ffwd X1 layer
tic
if(c1<1e-5) % If uncorrelated
    nspikeX1=poissrnd(Nx1*rx1*T);
    st=rand(nspikeX1,1)*T;
    sx1=zeros(2,numel(st));
    sx1(1,:)=sort(st);
    sx1(2,:)=randi(Nx1,1,numel(st)); % neuron indices
    clear st;
else % If correlated
    rm=rx1/c1; % Firing rate of mother process
    nstm=poissrnd(rm*T); % Number of mother spikes
    stm=rand(nstm,1)*T; % spike times of mother process
    maxnsx=T*rx1*Nx1*1.2; % Max num spikes
    sx1=zeros(2,maxnsx);
    ns=0;
    for j=1:Nx1  % For each ffwd spike train
        ns0=binornd(nstm,c1); % Number of spikes for this spike train
        st=randsample(stm,ns0); % Sample spike times randomly
        st=st+taujitter*randn(size(st)); % jitter spike times
        st=st(st>0 & st<T); % Get rid of out-of-bounds times
        ns0=numel(st); % Re-compute spike count
        sx1(1,ns+1:ns+ns0)=st; % Set the spike times and indices        
        sx1(2,ns+1:ns+ns0)=j;
        ns=ns+ns0;
    end

    % Get rid of padded zeros
    sx1 = sx1(:,sx1(1,:)>0);
    
    % Sort by spike time
    [~,I] = sort(sx1(1,:));
    sx1 = sx1(:,I);
    
    
    nspikeX1=size(sx1,2);
    
end
tGenx=toc;
disp(sprintf('\nTime to generate X_1 ffwd spikes: %.2f sec',tGenx))




%%% Make (correlated) Poisson spike times for ffwd X2 layer
tic
if(c2<1e-5) % If uncorrelated
    nspikeX2=poissrnd(Nx2*rx2*T);
    st=rand(nspikeX2,1)*T;
    sx2=zeros(2,numel(st));
    sx2(1,:)=sort(st);
    sx2=sx2(1,sx2(1,:)>T_start_stim & sx2(1,:)<T_end_stim );
    sx2(2,:)=randi(Nx2,1,length(sx2(1,:)))+Nx1; % neuron indices
    clear st;
    nspikeX2 = length(sx2(1,:));
else % If correlated
    rm=rx2/c2; % Firing rate of mother process
    nstm=poissrnd(rm*T); % Number of mother spikes
    stm=rand(nstm,1)*T; % spike times of mother process    
    maxnsx=T*rx2*Nx2*1.2; % Max num spikes
    sx2=zeros(2,maxnsx);
    ns=0;
    for j=1:Nx2  % For each ffwd spike train
        ns0=binornd(nstm,c2); % Number of spikes for this spike train
        st=randsample(stm,ns0); % Sample spike times randomly
        st=st+taujitter*randn(size(st)); % jitter spike times
        st=st(st>T_start_stim & st<T_end_stim); % Get rid of out-of-bounds times
        ns0=numel(st); % Re-compute spike count
        sx2(1,ns+1:ns+ns0)=st; % Set the spike times and indices        
        sx2(2,ns+1:ns+ns0)=j+Nx1; %Nx2 neurons are labeled 1001-2000 (after Nx1 cells).
        ns=ns+ns0;
    end

    % Get rid of padded zeros
    sx2 = sx2(:,sx2(1,:)>0);
    
    % Sort by spike time
    [~,I] = sort(sx2(1,:));
    sx2 = sx2(:,I);
    
    nspikeX2=size(sx2,2);
    
end
tGenx=toc;
disp(sprintf('\nTime to generate X_2 ffwd spikes: %.2f sec',tGenx))

% Neuron parameters
Cm=1;
gL=1/15;
EL=-72;
Vth=-50;
Vre=-75;
DeltaT=1;
VT=-55;

% Plasticity EI params
Jmax = -200/sqrt(N);
eta1=0.0007/Jmax; % Learning rate
tauSTDP=200;
rho1=0.010; % Target rate 10Hz
alpha1=2*rho1*tauSTDP;

% Plasticity II parameters. 
Jmax1 = -500/sqrt(N);
eta2=-0.0/Jmax1; % Learning rate
rho2=0.020; % Target rate 10Hz
alpha2=2*rho2*tauSTDP;


% Random initial voltages
V0=rand(N,1)*(VT-Vre)+Vre;

% Maximum number of spikes for all neurons
% in simulation. Make it 50Hz across all neurons
% If there are more spikes, the simulation will
% terminate
maxns=ceil(.05*N*T);

% Indices of neurons to record currents, voltages
nrecord0=2; % Number to record from each population
Irecord=[randperm(Ne,nrecord0) randperm(Ni,nrecord0)+Ne];
numrecord=numel(Irecord); % total number to record

% Synaptic weights I to E1 to record. E1 are stimulated.
% The first row of Jrecord is the postsynaptic indices
% The second row is the presynaptic indices
nJrecord0=2000; % Number to record
[II,JJ]=find(J(1:Ne1,Ne+1:N)); % Find non-zero I to E weights
III=randperm(numel(II),nJrecord0); % Choose some at random to record
II=II(III);
JJ=JJ(III);
Jrecord=[II JJ+Ne]'; % Record these
numrecordJ=size(Jrecord,2);
if(size(Jrecord,1)~=2)
    error('Jrecord must be 2xnumrecordJ');
end


% Synaptic weights IE2 to record. E2 are NOT stimulated.
% The first row of Jrecord is the postsynaptic indices
% The second row is the presynaptic indices
nJrecord1=2000; % Number to record
[II1,JJ1]=find(J(Ne1+1:Ne,Ne+1:N)); % Find non-zero I to E weights
III1=randperm(numel(II1),nJrecord1); % Choose some at random to record
II1=II1(III1);
JJ1=JJ1(III1);
Jrecord_1=[II1+Ne1 JJ1+Ne]'; % Record these
numrecordJ1=size(Jrecord_1,2);
if(size(Jrecord_1,1)~=2)
    error('Jrecord must be 2xnumrecordJ');
end

% Synaptic weights II to record.
% The first row of Jrecord is the postsynaptic indices
% The second row is the presynaptic indices
nJrecord2=1000; % Number of ii synapses to record
[II2,JJ2]=find(J(Ne+1:N,Ne+1:N)); % Find non-zero i to i weights
III2=randperm(numel(II2),nJrecord2); % Choose some at random to record
II2=II2(III2);
JJ2=JJ2(III2);
Jrecord_2=[II2+Ne JJ2+Ne]'; % Record these
numrecordJ2=size(Jrecord_2,2);
if(size(Jrecord_2,1)~=2)
    error('Jrecord must be 2xnumrecordJ');
end


% Number of time bins to average over when recording
nBinsRecord=10;
dtRecord=nBinsRecord*dt;
timeRecord=dtRecord:dtRecord:T;
Ntrec=numel(timeRecord);

% Integer division function
IntDivide=@(n,k)(floor((n-1)/k)+1);

V=V0;
Ie=zeros(N,1);
Ii=zeros(N,1);
Ix1=zeros(N,1);
Ix2=zeros(N,1);
x=zeros(N,1);
IeRec=zeros(numrecord,Ntrec);
IiRec=zeros(numrecord,Ntrec);
IxRec=zeros(numrecord,Ntrec);
% VRec=zeros(numrecord,Ntrec);
% wRec=zeros(numrecord,Ntrec);
JRec=zeros(1,Ntrec);
JRec_1 = zeros(1,Ntrec);
JRec_2=zeros(1,Ntrec);
iFspike1=1;
iFspike2=1;
s=zeros(2,maxns);
nspike=0;
TooManySpikes=0;
tic
for i=1:numel(time)
    
    
    % Propogate ffwd X1 spikes
    while(sx1(1,iFspike1)<=time(i) && iFspike1<nspikeX1)
        jpre=sx1(2,iFspike1);
        Ix1=Ix1+Jx(:,jpre)/taux;
        iFspike1=iFspike1+1;
    end
    % Propogate ffwd spikes
    while(sx2(1,iFspike2)<=time(i) && iFspike2<nspikeX2)
        jpre=sx2(2,iFspike2);
        Ix2=Ix2+Jx(:,jpre)/taux;
        iFspike2=iFspike2+1;
    end
    
    % Euler update to V
    V=V+(dt/Cm)*(Istim(i)*Jstim+Ie+Ii+Ix1+Ix2+gL*(EL-V)+gL*DeltaT*exp((V-VT)/DeltaT));
    
    % Find which neurons spiked
    Ispike=find(V>=Vth);
    
    % If there are spikes
    if(~isempty(Ispike))
        
        % Store spike times and neuron indices
        if(nspike+numel(Ispike)<=maxns)
            s(1,nspike+1:nspike+numel(Ispike))=time(i);
            s(2,nspike+1:nspike+numel(Ispike))=Ispike;
        else
            TooManySpikes=1;
            break;
        end
        
        
        % Update synaptic currents
        Ie=Ie+sum(J(:,Ispike(Ispike<=Ne)),2)/taue;
        Ii=Ii+sum(J(:,Ispike(Ispike>Ne)),2)/taui;
        
        % If there is EI plasticity
        if(eta1~=0)
            % Update synaptic weights according to plasticity rules
            % I to E after an I spike
            J(1:Ne,Ispike(Ispike>Ne))=J(1:Ne,Ispike(Ispike>Ne))+ ...
                -repmat(eta1*(x(1:Ne)-alpha1),1,nnz(Ispike>Ne)).*(J(1:Ne,Ispike(Ispike>Ne)));
            % E to I after an E spike
            J(Ispike(Ispike<=Ne),Ne+1:N)=J(Ispike(Ispike<=Ne),Ne+1:N)+ ...
                -repmat(eta1*x(Ne+1:N)',nnz(Ispike<=Ne),1).*(J(Ispike(Ispike<=Ne),Ne+1:N));
        end
        
        
        % If there is ii Hebbian plasticity
        if(eta2~=0)
            % Update synaptic weights according to plasticity rules
            % I to I after a presyanptic spike
            J(Ne+1:N,Ispike(Ispike>Ne))=J(Ne+1:N,Ispike(Ispike>Ne))+ ...
                +repmat(eta2*(x(Ne+1:N)-alpha2),1,nnz(Ispike>Ne)).*(J(Ne+1:N,Ispike(Ispike>Ne)));
            % I to I after a postsynaptic spike
            J(Ispike(Ispike>Ne),Ne+1:N)=J(Ispike(Ispike>Ne),Ne+1:N)+ ...
                +repmat(eta2*x(Ne+1:N)',nnz(Ispike>Ne),1).*(J(Ispike(Ispike>Ne),Ne+1:N));
        end
        
        % Update rate estimates for plasticity rules
        x(Ispike)=x(Ispike)+1;
        
        % Update cumulative number of spikes
        nspike=nspike+numel(Ispike);
    end
    
    % Euler update to synaptic currents
    Ie=Ie-dt*Ie/taue;
    Ii=Ii-dt*Ii/taui;
    Ix1=Ix1-dt*Ix1/taux;
    Ix2=Ix2-dt*Ix2/taux;
    
    
    % Update time-dependent firing rates for plasticity
    x(1:Ne)=x(1:Ne)-dt*x(1:Ne)/tauSTDP;
    x(Ne+1:end)=x(Ne+1:end)-dt*x(Ne+1:end)/tauSTDP;
    
    % This makes plots of V(t) look better.
    % All action potentials reach Vth exactly.
    % This has no real effect on the network sims
    V(Ispike)=Vth;
    
    % Store recorded variables
    ii=IntDivide(i,nBinsRecord);
    IeRec(:,ii)=IeRec(:,ii)+Ie(Irecord);
    IiRec(:,ii)=IiRec(:,ii)+Ii(Irecord);
    %     IxRec(:,ii)=IxRec(:,ii)+Ix1(Irecord);
    %     VRec(:,ii)=VRec(:,ii)+V(Irecord);
    JRec(1,ii)=sqrt(N)*mean(J(sub2ind(size(J),Jrecord(1,:),Jrecord(2,:))));
    JRec_1(1,ii)=sqrt(N)*mean(J(sub2ind(size(J),Jrecord_1(1,:),Jrecord_1(2,:))));
    JRec_2(1,ii)=sqrt(N)*mean(J(sub2ind(size(J),Jrecord_2(1,:),Jrecord_2(2,:))));
    
    % Reset mem pot.
    V(Ispike)=Vre;
    
    if i/dt == T_start_stim
        Je1i_before = nonzeros(sqrt(N)*J(1:Ne1,Ne+1:N));
        Je2i_before = nonzeros(sqrt(N)*J(Ne1+1:Ne,Ne+1:N));
        Jii_before = nonzeros(sqrt(N)*J(Ne+1:N,Ne+1:N));
        Je1i_before = datasample(Je1i_before,50000,'Replace',false); % Sample from full matrix
        Je2i_before = datasample(Je2i_before,50000,'Replace',false); % Sample from full matrix
        Jii_before = datasample(Jii_before,50000,'Replace',false); % Sample from full matrix

    end
    if time(i) == T_end_stim
        Je1i_during = nonzeros(sqrt(N)*J(1:Ne1,Ne+1:N));
        Je2i_during = nonzeros(sqrt(N)*J(Ne1+1:Ne,Ne+1:N));
        Jii_during = nonzeros(sqrt(N)*J(Ne+1:N,Ne+1:N));
        Je1i_during = datasample(Je1i_during,50000,'Replace',false); % Sample from full matrix
        Je2i_during = datasample(Je2i_during,50000,'Replace',false); % Sample from full matrix
        Jii_during = datasample(Jii_during,50000,'Replace',false); % Sample from full matrix
    end
    if time(i) == T
        Je1i_after = nonzeros(sqrt(N)*J(1:Ne1,Ne+1:N));
        Je2i_after = nonzeros(sqrt(N)*J(Ne1+1:Ne,Ne+1:N));
        Jii_after = nonzeros(sqrt(N)*J(Ne+1:N,Ne+1:N));
        Je1i_after = datasample(Je1i_after,50000,'Replace',false); % Sample from full matrix
        Je2i_after = datasample(Je2i_after,50000,'Replace',false); % Sample from full matrix
        Jii_after = datasample(Jii_after,50000,'Replace',false); % Sample from full matrix
    end
    
end
IeRec=IeRec/nBinsRecord; % Normalize recorded variables by # bins
IiRec=IiRec/nBinsRecord;
% IxRec=IxRec/nBinsRecord;
% VRec=VRec/nBinsRecord;
s=s(:,1:nspike); % Get rid of padding in s
tSim=toc;
disp(sprintf('\nTime for simulation: %.2f min',tSim/60))


%% Make a raster plot of first 500 neurons
% % s(1,:) are the spike times
% % s(2,:) are the associated neuron indices
% figure
% plot(s(1,s(2,:)<N+1),s(2,s(2,:)<N+1),'k.','markersize',0.5)
% xlim([0 2000])
% xlabel('time (ms)')
% ylabel('Neuron index')
spikeTimes=s(1,s(2,:)<N+1);
spikeIndex=s(2,s(2,:)<N+1);

% Mean rate of each neuron (excluding burn-in period)
Tburn=T/2;
re1Sim=hist(s(2,s(1,:)>Tburn & s(2,:)<=Ne1),1:Ne1)/(T-Tburn);
re2Sim=hist(s(2,s(1,:)>Tburn & s(2,:)<=Ne2),Ne1:Ne1+Ne2)/(T-Tburn);
riSim=hist(s(2,s(1,:)>Tburn & s(2,:)>Ne)-Ne,1:Ni)/(T-Tburn);

% Mean rate over E and I pops
re1Mean=mean(re1Sim);
re2Mean=mean(re2Sim);
riMean=mean(riSim);
disp(sprintf('\nMean E1, E2, and I rates from sims: %.2fHz %.2fHz %.2fHz',1000*re1Mean,1000*re2Mean,1000*riMean))

% Time-dependent mean rates
dtRate=100; % ms
e1RateT=hist(s(1,s(2,:)<=Ne1),1:dtRate:T)/(dtRate*Ne1);
e2RateT=hist( s(1,s(2,:)>Ne1 & s(2,:)<=Ne1+Ne2),1:dtRate:T)/(dtRate*Ne2);
iRateT=hist(s(1,s(2,:)>Ne),1:dtRate:T)/(dtRate*Ni);
Vector_Time_Rate = (dtRate:dtRate:T)/1000;

% Plot time-dependent rates
figure
plot((dtRate:dtRate:T)/1000,1000*e1RateT)
hold on
plot((dtRate:dtRate:T)/1000,1000*e2RateT)
plot((dtRate:dtRate:T)/1000,1000*iRateT)
legend('r_e1','r_e2','r_i')
ylabel('rate (Hz)')
xlabel('time (s)')

%% If plastic, plot mean connection weights over time
if(eta1~=0)
    figure; hold on
    plot(timeRecord/1000,JRec, 'linewidth',2)
    plot(timeRecord/1000,JRec_1, 'linewidth',2)
    plot(timeRecord/1000,JRec_2, 'linewidth',2)
    legend('IEresp','IEnonresp','II')
    xlabel('time (s)')
    ylabel('Synaptic weight')

    figure;
    histogram(nonzeros(J(1:Ne,Ne+1:N))*sqrt(N), 40)
    xlabel('J_{e1i}')
    ylabel('Count')
end


%% Compute correlations before stimulation.
% Compute spike count covariances over windows of size
% winsize starting at time T1 and ending at time T2.
winsize=250;
T1=T_start_stim/2; % Burn-in period of 250 ms
T2=T_start_stim;   % Compute covariances until end of simulation
C=SpikeCountCov(s,N,T1,T2,winsize);

% Get mean spike count covariances over each sub-pop
[II,JJ]=meshgrid(1:N,1:N);
mCe1e1=mean(C(II<=Ne1 & JJ<=II));
mCe1e2=mean(C(II<=Ne1 & JJ<=Ne1+Ne2));
mCe1i=mean(C(II<=Ne1 & JJ>Ne));
mCe2e2=mean(C(II>Ne1 & JJ<=Ne1+Ne2));
mCe2i=mean(C(II>Ne1 & JJ>Ne));
mCii=mean(C(II>Ne & JJ>II));

% Mean-field spike count cov matrix
% Compare this to the theoretical prediction
mC_before_stim=[mCe1e1 mCe1e2 mCe1i; mCe1e2 mCe2e2 mCe2i; mCe1i mCe2i mCii];

% Compute spike count correlations
% This takes a while, so make it optional
ComputeSpikeCountCorrs=1;
if(ComputeSpikeCountCorrs)
    
    % Get correlation matrix from cov matrix
    tic
    R=corrcov(C);
    toc
    
    Corrs_before = R(II<=N & JJ<II);
    Corrs_before = datasample(Corrs_before,50000,'Replace',false); % Sample from full matrix
    
    mRe1e1=nanmean(R(II<=Ne1 & JJ<II));
    mRe1e2=nanmean(R(II<=Ne1 & JJ<Ne1+Ne2));
    mRe1i=nanmean(R(II<=Ne1 & JJ>Ne));
    mRe2e2=nanmean(R(II>Ne1 & JJ<Ne1+Ne2));
    mRe2i=nanmean(R(II>Ne1 & JJ>Ne));
    mRii=nanmean(R(II>Ne & JJ>II));
    
    % Mean-field spike count correlation matrix
    mR_before_stim=[mRe1e1 mRe1e2 mRe1i; mRe1e2 mRe2e2 mRe2i; mRe1i mRe2i mRii]
    
    
end

%% Compute correlations during stimulation.
%%% All the code below computes spike count covariances and correlations
%%% We want to compare the resulting covariances to what is predicted by
%%% the theory, first for non-plastic netowrks (eta=0)

% Compute spike count covariances over windows of size
% winsize starting at time T1 and ending at time T2.
winsize=250;
T1=(T_start_stim+T_end_stim)/2; % Burn-in period of 250 ms
T2=T_end_stim;   % Compute covariances until end of simulation
C=SpikeCountCov(s,N,T1,T2,winsize);


% Get mean spike count covariances over each sub-pop
[II,JJ]=meshgrid(1:N,1:N);
mCe1e1=mean(C(II<=Ne1 & JJ<=II));
mCe1e2=mean(C(II<=Ne1 & JJ<=Ne1+Ne2));
mCe1i=mean(C(II<=Ne1 & JJ>Ne));
mCe2e2=mean(C(II>Ne1 & JJ<=Ne1+Ne2));
mCe2i=mean(C(II>Ne1 & JJ>Ne));
mCii=mean(C(II>Ne & JJ>II));

% Mean-field spike count cov matrix
% Compare this to the theoretical prediction
mC_during_stim=[mCe1e1 mCe1e2 mCe1i; mCe1e2 mCe2e2 mCe2i; mCe1i mCe2i mCii];

% Compute spike count correlations
% This takes a while, so make it optional
ComputeSpikeCountCorrs=1;
if(ComputeSpikeCountCorrs)
    
    % Get correlation matrix from cov matrix
    tic
    R=corrcov(C);
    toc
    
    Corrs_during = R(II<=N & JJ<II);
    Corrs_during = datasample(Corrs_during,50000,'Replace',false); % Sample from full matrix

    
    mRe1e1=nanmean(R(II<=Ne1 & JJ<II));
    mRe1e2=nanmean(R(II<=Ne1 & JJ<Ne1+Ne2));
    mRe1i=nanmean(R(II<=Ne1 & JJ>Ne));
    mRe2e2=nanmean(R(II>Ne1 & JJ<Ne1+Ne2));
    mRe2i=nanmean(R(II>Ne1 & JJ>Ne));
    mRii=nanmean(R(II>Ne & JJ>II));
    
    % Mean-field spike count correlation matrix
    mR_during_stim=[mRe1e1 mRe1e2 mRe1i; mRe1e2 mRe2e2 mRe2i; mRe1i mRe2i mRii]
    
    
end



%% Compute correlations after stimulation.
%%% All the code below computes spike count covariances and correlations
%%% We want to compare the resulting covariances to what is predicted by
%%% the theory, first for non-plastic netowrks (eta=0)

% Compute spike count covariances over windows of size
% winsize starting at time T1 and ending at time T2.
winsize=250;
T1=(T_end_stim + T)/2; % Burn-in period of 250 ms
T2=T;   % Compute covariances until end of simulation
C=SpikeCountCov(s,N,T1,T2,winsize);


% Get mean spike count covariances over each sub-pop
[II,JJ]=meshgrid(1:N,1:N);
mCe1e1=mean(C(II<=Ne1 & JJ<=II));
mCe1e2=mean(C(II<=Ne1 & JJ<=Ne1+Ne2));
mCe1i=mean(C(II<=Ne1 & JJ>Ne));
mCe2e2=mean(C(II>Ne1 & JJ<=Ne1+Ne2));
mCe2i=mean(C(II>Ne1 & JJ>Ne));
mCii=mean(C(II>Ne & JJ>II));

% Mean-field spike count cov matrix
% Compare this to the theoretical prediction
mC_after_stim=[mCe1e1 mCe1e2 mCe1i; mCe1e2 mCe2e2 mCe2i; mCe1i mCe2i mCii];

% Compute spike count correlations
% This takes a while, so make it optional
ComputeSpikeCountCorrs=1;
if(ComputeSpikeCountCorrs)
    
    % Get correlation matrix from cov matrix
    tic
    R=corrcov(C);
    toc
    
    Corrs_after = R(II<=N & JJ<II);
    Corrs_after = datasample(Corrs_after,50000,'Replace',false); % Sample from full matrix

    mRe1e1=nanmean(R(II<=Ne1 & JJ<II));
    mRe1e2=nanmean(R(II<=Ne1 & JJ<Ne1+Ne2));
    mRe1i=nanmean(R(II<=Ne1 & JJ>Ne));
    mRe2e2=nanmean(R(II>Ne1 & JJ<Ne1+Ne2));
    mRe2i=nanmean(R(II>Ne1 & JJ>Ne));
    mRii=nanmean(R(II>Ne & JJ>II));
    
    % Mean-field spike count correlation matrix
    mR_after_stim=[mRe1e1 mRe1e2 mRe1i; mRe1e2 mRe2e2 mRe2i; mRe1i mRe2i mRii]
    
    
end

%% Save variables
save('./Stim_E_ei_ii_Corr.mat', 'e1RateT','e2RateT','iRateT','dtRate','T',...
    'JRec','JRec_1','JRec_2','timeRecord','N','rx1','rx2','T_start_stim','T_end_stim',...
    'c1','c2','Vector_Time_Rate',...
    'mR_after_stim','mR_before_stim','mR_during_stim',...
    'Corrs_before','Corrs_during','Corrs_after','Jei_initial',...
    'Je1i_before','Je2i_before','Jii_before',...
    'Je1i_during','Je2i_during','Jii_during',...
    'Je1i_after','Je2i_after','Jii_after');

fprintf('Simulation has finished.\n')




