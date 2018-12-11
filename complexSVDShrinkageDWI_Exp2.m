%COMPLEXSVDSHRINKAGEDWI_EXP2 script performs the experiment included in 
%Fig. 8 of the manuscript ''Complex diffusion-weighted image estimation 
%via matrix recovery under general noise models'', L. Cordero-Grande, D. 
%Christiaens, J. Hutter, A.N. Price, and J.V. Hajnal

clearvars
parR.Verbosity=2;%Level of verbosity, from 0 to 3
gpu=gpuDeviceCount;%Detects whether gpu computations are possible
if gpu;dev=gpuDevice;end

addpath(genpath('.'));%Add code
pathData='../complexSVDShrinkageDWIData';%Data path

%READ DATA
if parR.Verbosity>0
    fprintf('Experiment on magnitude versus complex denoising / comparison with the literature\n');
    fprintf('Reading input data...\n');
end
load(fullfile(pathData,'recFig08.mat'));
if parR.Verbosity>0;fprintf('Finished reading input data\n');end

%EXPERIMENT PARAMETERS
typExec='Quick';%For quick computations to inspect behaviour and results, any other string, for instance 'Reproduce' will strictly reproduce the experiment in the paper
NoiEstMethV={'None','Exp2'};%See eqs. 21 and 22, one of the following: 'None' / 'Exp1' / 'Exp2' / 'Medi'
ShrinkMethV={'Frob','Exp2'};%Frob stands for Frobenius cost. One of the following: 'Hard' / 'Soft' / 'Frob' / 'Oper' / 'Nucl' / 'Exp1' / 'Exp2'
UseComplexDataV=[true false];%false for not to use complex data

%MAIN PARAMETERS
parR.UseLinearPhaseCorrection=true;%false for not to correct for linear phase
parR.UseNoiseStandardization=false;%false for not to operate in noise units but in signal units
parR.useRatioAMSE=2;%To compute the NAMSE (1), AMSE (0) or both AMSE and AMSS (square of signal level) (2)
parR.ESDMeth=3;%0->Use simulation / 1-> Use SPECTRODE / 2-> Use MIXANDMIX / 3-> Force computation of simulated spectra (to get AMSE estimates when using noise estimates instead of noise modeling)
parR.ESDTol=1e-2;%Tolerance for ESD computations (role depends on the method)
parR.NR=1;%Number of realizations of random matrix simulations
parR.DirInd=0;%To accelerate by using independence of covariances along a given direction
parR.Gamma=0.2:0.05:0.95;%Random matrix aspect ratio, vector of values interpreted as candidates for patch size estimations
parR.Subsampling=[2 2 2];%Subsampling factor for patch construction, bigger values produce quicker denoising, but if too big holes may appear in the resulting data
if strcmp(typExec,'Quick');parR.Subsampling=[4 4 4];end
parR.DrawFact=3;%Factor to multiply the subsampling factor to sweep the image space to estimate patch sizes

%NUMERIC PARAMETERS
thNoise=1e-3;%Mask out below this value

strTyp={'complex','magnitude'};
strMet={'our','Veraart'};
T=2;%Complex data / Magnitude
N=length(NoiEstMethV);%Noise estimation method
xv=cell(T,N);sigmav=cell(T,N);Rv=cell(T,N);amsev=cell(T,N);gammav=cell(T,N);
for t=1:T%First complex, second magnitude
    parR.UseComplexData=UseComplexDataV(t);
    for n=1:length(NoiEstMethV)%First ours, second Veraart
        if parR.Verbosity>0
            fprintf('Retrieval using %s information and %s method...\n',strTyp{t},strMet{n});
            if gpu;wait(dev);end
            tsta=tic;        
        end        
        parR.NoiEstMeth=NoiEstMethV{n};parR.ShrinkMeth=ShrinkMethV{n};
        UpsInv=UpsilonInv;
        x=y;
        if gpu;[x,UpsInv]=parUnaFun({x,UpsInv},@gpuArray);end
        
        %MAGNITUDE-ONLY
        if ~parR.UseComplexData;x=abs(x);end%Using magnitude data
        
        %ESTIMATE AND CORRECT FOR LINEAR PHASE
        if parR.UseLinearPhaseCorrection && parR.UseComplexData
            Phi=ridgeDetection(x,1:2);
            x=bsxfun(@times,x,conj(Phi));
            Phi=gather(Phi);
        end

        %STANDARDIZE NOISE
        M=UpsInv;M=single(M>thNoise);%Mask
        mUps=mean(UpsInv(UpsInv>=thNoise));%Mean noise
        if parR.UseNoiseStandardization
            UpsInv(UpsInv<=thNoise)=mUps;
            x=bsxfun(@times,x,M./UpsInv);
        end

        %ADD MEAN LEVEL OF NOISE OUTSIDE THE MASK SO THAT NOISE ESTIMATION BECOMES INDEPENDENT FROM MASKING
        if ~strcmp(parR.NoiEstMeth,'None')            
            if parR.UseNoiseStandardization;no=plugNoise(x);else no=mUps*plugNoise(x);end
            if ~parR.UseComplexData;no=abs(no);end
            x=bsxfun(@times,x,M)+bsxfun(@times,no,1-M);no=[];
        end

        %SVD PATCH BASED RECOVERY
        [x,sigma,R,amse,gamma]=patchSVShrinkage(x,3,voxsiz,parR,cov);                       

        %DESTANDARDIZE NOISE
        if parR.UseNoiseStandardization;x=bsxfun(@times,x,UpsInv);
        elseif ~strcmp(parR.NoiEstMeth,'None');x=bsxfun(@times,x,M);
        end 

        %REINCORPORATE LINEAR PHASE
        if parR.UseLinearPhaseCorrection && parR.UseComplexData
            if gpu;Phi=gpuArray(Phi);end
            x=bsxfun(@times,x,Phi);Phi=[];
        end    
        
        xv{t,n}=gather(x);
        sigmav{t,n}=gather(sigma);
        Rv{t,n}=gather(R);
        amsev{t,n}=gather(amse);
        gammav{t,n}=gather(gamma);
        parR.Gamma=gamma;%To use the same aspect ratio for each compared case
        
        if parR.Verbosity>0
            if gpu;wait(dev);end
            fprintf('Retrieval time using %s information and %s method %.2fs\n',strTyp{t},strMet{n},toc(tsta));            
        end   
    end
end

if parR.Verbosity>0;fprintf('Saving results...\n');end
save(fullfile(pathData,'retFig08.mat'),'xv','sigmav','Rv','amsev','gammav','-v7.3');
if parR.Verbosity>0;fprintf('Finished saving results\n');end
