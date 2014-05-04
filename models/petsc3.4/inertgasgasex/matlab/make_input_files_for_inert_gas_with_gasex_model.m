% Set toplevel path to GCMs configuration
% base_path='/data2/spk/TransportMatrixConfigs/MITgcm_2.8deg';
% base_path='/data2/spk/TransportMatrixConfigs/MITgcm_ECCO';
base_path='/data2/spk/TransportMatrixConfigs/MITgcm_ECCO_v4';

periodicForcing=1
periodicMatrix=1

dt=43200; % time step to use

rearrangeProfiles=1
bigMat=0
writeFiles=1
writeTMs=1
useCoarseGrainedMatrix=0
writePCFiles=0

oceanCarbonBasePath='/data2/spk/OceanCarbon';
%-----------------------------------
% Compute winds online from high-frequency u and v winds; default is to read CORE-2 winds
% Only valid if periodicForcing=1
useSeparateWinds=0;
corePath=fullfile(oceanCarbonBasePath,'CORE');
%-----------------------------------

% Set path names, etc.
load(fullfile(base_path,'config_data'))

matrixPath=fullfile(base_path,matrixPath);

explicitMatrixFileBase=fullfile(base_path,explicitMatrixFileBase);
implicitMatrixFileBase=fullfile(base_path,implicitMatrixFileBase);

explicitAnnualMeanMatrixFile=fullfile(base_path,explicitAnnualMeanMatrixFile);
implicitAnnualMeanMatrixFile=fullfile(base_path,implicitAnnualMeanMatrixFile);

preconditionerMatrixFile=fullfile(base_path,preconditionerMatrixFile);

gcmDataPath=fullfile(base_path,'GCM');
bgcDataPath=fullfile(base_path,'BiogeochemData');
freshWaterForcingFile=fullfile(gcmDataPath,'FreshWaterForcing_gcm');
empFixFile=fullfile(gcmDataPath,empFixFile);

% model specific data
if strcmp(gcmConfigName,'MITgcm_2.8deg')
  iceFile=fullfile(bgcDataPath,'fice');
  windFile=fullfile(bgcDataPath,'tren_speed');
elseif strcmp(gcmConfigName,'MITgcm_ECCO')
  iceFile=fullfile(bgcDataPath,'nasa_icefraction_mth-2d');
  windFile=fullfile(bgcDataPath,'tren_speed_mth-2d');
elseif strcmp(gcmConfigName,'MITgcm_ECCO_v4')
  iceFile=fullfile(bgcDataPath,'Fice');
  windFile=fullfile(bgcDataPath,'EXF_wspeed');
else
  error('ERROR: Unknown configuration!')
end

%
gridFile=fullfile(base_path,'grid');
boxFile=fullfile(matrixPath,'Data','boxes');
profilesFile=fullfile(matrixPath,'Data','profile_data');

load(gridFile,'nx','ny','nz','dznom','x','y','z','deltaT','gridType')

dtMultiple=dt/deltaT;
if rem(dt,deltaT)
  error('ERROR: Incorrect time step specified! dt must be divisible by deltaT.')
end
disp(['dtMultiple is set to ' num2str(dtMultiple)])

if strcmp(gridType,'llc_v4')
  load(boxFile,'XboxnomGlob','YboxnomGlob','ZboxnomGlob','izBoxGlob','nb','volbglob')
  nb=sum(nb);
  Xboxnom=XboxnomGlob;
  Yboxnom=YboxnomGlob;
  Zboxnom=ZboxnomGlob;
  izBox=izBoxGlob;
  volb=volbglob;
else
  load(boxFile,'Xboxnom','Yboxnom','Zboxnom','izBox','nb','volb')
end

Ib=find(izBox==1);
nbb=length(Ib);

if rearrangeProfiles || bigMat
  load(profilesFile,'Ip_pre','Ir_pre','Ip_post','Ir_post','Irr')
  Ip=Ip_pre;
  Ir=Ir_pre;
end

if useCoarseGrainedMatrix
  error('NOT FULLY IMPLEMENTED YET!')
end

if periodicForcing
  nm=12;
else
  nm=1;
end

% Use steady state T/S from GCM. Note we always load seasonal data here.
load(fullfile(gcmDataPath,'Theta_gcm'),'Tgcm')
load(fullfile(gcmDataPath,'Salt_gcm'),'Sgcm')
Tsteady=gridToMatrix(Tgcm,[],boxFile,gridFile);
Ssteady=gridToMatrix(Sgcm,[],boxFile,gridFile);

clear Tgcm Sgcm % make some space

% now take annual mean if necessary
if ~periodicForcing
  Tsteady=mean(Tsteady,2);
  Ssteady=mean(Ssteady,2);
end

% Surface forcing data
load(iceFile,'Fice')
Ficeb=gridToMatrix(Fice,Ib,boxFile,gridFile,1);
if ~periodicForcing
  Ficeb=mean(Ficeb,2);
end

if ~periodicForcing && useSeparateWinds==1
  useSeparateWinds=0;
  disp('Warning: useSeparateWinds has been set to 0 because periodicForcing is 0')
end

if useSeparateWinds
% Compute winds online from u and v winds
  [u10b,Tcore,lon,lat]=load_core_variable(fullfile(corePath,'u_10.15JUNE2009.nc'),'U_10',Xboxnom(Ib),Yboxnom(Ib));
  [v10b,Tcore,lon,lat]=load_core_variable(fullfile(corePath,'v_10.15JUNE2009.nc'),'V_10',Xboxnom(Ib),Yboxnom(Ib));
else
  load(windFile,'wind')
  windb=gridToMatrix(wind,Ib,boxFile,gridFile,1);  
  if ~periodicForcing
	windb=mean(windb,2);  
  end
end

atmospb=load_ocmip_variable([],'P',Xboxnom(Ib),Yboxnom(Ib));  
if ~periodicForcing
  atmospb=mean(atmospb,2);
end

if rearrangeProfiles
  Xboxnom=Xboxnom(Ir);
  Yboxnom=Yboxnom(Ir);
  Zboxnom=Zboxnom(Ir);
  izBox=izBox(Ir);
  Tsteady=Tsteady(Ir,:);
  Ssteady=Ssteady(Ir,:);
  Ib=find(izBox==1);
%
  Ip=Ip_post;
  Ir=Ir_post;
end  

% Initial condition
TR=repmat(0,[nb 1]);

if useCoarseGrainedMatrix
% Coarse grain initial conditions and forcing data
end

if writeFiles
% Transport matrices
  if writeTMs
%   Explicit transport matrix
	I=speye(nb,nb);
	if ~periodicMatrix
      disp('loading annual mean explicit TM')	
      load(explicitAnnualMeanMatrixFile,'Aexpms')	
	  if rearrangeProfiles
		Aexpms=Aexpms(Ir_pre,Ir_pre); % rearrange
	  end      
	  % make discrete
	  Aexpms=dt*Aexpms;
	  Aexpms=I+Aexpms;
	  if useCoarseGrainedMatrix
		Aexpms=Beta*Aexpms*M; % coarse-grained explicit transport matrix
	  end        
	  writePetscBin('Ae.petsc',Aexpms,[],1)
	else
      % load each month from separate file
      disp('loading monthly mean explicit TMs')	      
	  for im=1:12 
		fn=[explicitMatrixFileBase '_' sprintf('%02d',im)];
		load(fn,'Aexp')
		if rearrangeProfiles
		  Aexp=Aexp(Ir_pre,Ir_pre); % rearrange
		end
		% make discrete
		Aexp=dt*Aexp;
		Aexp=I+Aexp;
		if useCoarseGrainedMatrix
%         Not sure if this is really kosher!		  
		  Aexp=Beta*Aexp*M; % coarse-grained explicit transport matrix
		end
		writePetscBin(['Ae_' sprintf('%02d',im-1)],Aexp,[],1)
		clear Aexp
	  end
	end
%   Implicit transport matrix
	if ~periodicMatrix
      disp('loading annual mean implicit TM')		
      load(implicitAnnualMeanMatrixFile,'Aimpms')
      if dtMultiple~=1
		if bigMat % big matrix. do it a block at a time.
		  for is=1:nbb % change time step multiple
			Aimpms(Ip_pre{is},Ip_pre{is})=Aimpms(Ip_pre{is},Ip_pre{is})^dtMultiple;
		  end
		else
		  Aimpms=Aimpms^dtMultiple;
		end  
	  end	
	  if rearrangeProfiles
		Aimpms=Aimpms(Ir_pre,Ir_pre); % rearrange
	  end
	  if useCoarseGrainedMatrix
		Aimpms=Beta*Aimpms*M; % coarse-grained implicit transport matrix
	  end
	  writePetscBin('Ai.petsc',Aimpms,[],1)
	else
	  % load each month from separate file
      disp('loading monthly mean implicit TMs')	      	  
	  for im=1:12
		fn=[implicitMatrixFileBase '_' sprintf('%02d',im)];		
		load(fn,'Aimp')
		if dtMultiple~=1
		  if bigMat % big matrix. do it a block at a time.		
			for is=1:nbb % change time step multiple
			  Aimp(Ip_pre{is},Ip_pre{is})=Aimp(Ip_pre{is},Ip_pre{is})^dtMultiple;
			end
		  else
			Aimp=Aimp^dtMultiple;		
		  end
		end  
		if rearrangeProfiles
		  Aimp=Aimp(Ir_pre,Ir_pre); % rearrange
		end
		if useCoarseGrainedMatrix
		  Aimp=Beta*Aimp*M; % coarse-grained implicit transport matrix		
		end
		writePetscBin(['Ai_' sprintf('%02d',im-1)],Aimp,[],1)
		clear Aimp
	  end
	end
  end	  	  
% Initial conditions  
  writePetscBin('trini.petsc',TR)
% Surface forcing data
  if ~periodicForcing
	write_binary('fice.bin',Ficeb,'real*8')
	write_binary('wind.bin',windb,'real*8')	
	write_binary('atmosp.bin',atmospb,'real*8')	
  else
    for im=1:nm
	  write_binary(['fice_' sprintf('%02d',im-1)],Ficeb(:,im),'real*8')
	  write_binary(['atmosp_' sprintf('%02d',im-1)],atmospb(:,im),'real*8')	  
	  if ~useSeparateWinds
		write_binary(['wind_' sprintf('%02d',im-1)],windb(:,im),'real*8')	  
      end	  
	end
	if useSeparateWinds
	  for im=1:size(u10b,2)
		write_binary(['uwind_' sprintf('%02d',im-1)],u10b(:,im),'real*8')
		write_binary(['vwind_' sprintf('%02d',im-1)],v10b(:,im),'real*8')
	  end
    end	
  end
  if ~periodicForcing
	writePetscBin('Ts.petsc',Tsteady)
	writePetscBin('Ss.petsc',Ssteady)
  else
    for im=1:nm
	  writePetscBin(['Ts_' sprintf('%02d',im-1)],Tsteady(:,im))
	  writePetscBin(['Ss_' sprintf('%02d',im-1)],Ssteady(:,im))
    end    
  end    
% Grid data

% Profile data
  if rearrangeProfiles
    if ~useCoarseGrainedMatrix
      gStartIndices=repmat(0,[nbb 1]);
      gEndIndices=repmat(0,[nbb 1]);
      for is=1:nbb % loop over each surface point
        Ipl=Ip{is}; % indices for local profile (globally indexed)  
        gStartIndices(is)=Ipl(1);
        gEndIndices(is)=Ipl(end);
      end
    else % useCoarseGrainedMatrix
      gStartIndices=repmat(0,[nbbcg 1]);
      gEndIndices=repmat(0,[nbbcg 1]);
      for is=1:nbbcg % loop over each surface point
        Ipl=Ipcg{is}; % indices for local profile (globally indexed)  
        gStartIndices(is)=Ipl(1);
        gEndIndices(is)=Ipl(end);
      end  
    end  
    write_binary('gStartIndices.bin',[length(gStartIndices);gStartIndices],'int')
    write_binary('gEndIndices.bin',[length(gEndIndices);gEndIndices],'int')
  end
end

if useCoarseGrainedMatrix
  numProfiles=nbbcg;
else  
  numProfiles=nbb;
end
disp(['Number of Profiles in this Configuration: ' int2str(numProfiles)])

if writePCFiles
  pc=load(preconditionerMatrixFile,'Aexpms');
  if rearrangeProfiles
    A=pc.Aexpms(Ir_pre,Ir_pre);
  else
    A=pc.Aexpms;
  end
  clear pc  
  if useCoarseGrainedMatrix
    A=Beta*A*M;
    save pc_cg_data A nbbcg CGgrid CG Ipcg Ibcg dt
  else
    save pc_data A nbb nz nb Ip Ib dt
  end
end