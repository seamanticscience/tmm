base_path='/data2/spk/TransportMatrixConfigs/MITgcm_2.8deg';

load(fullfile(base_path,'config_data'))

matrixPath=fullfile(base_path,matrixPath);

gridFile=fullfile(base_path,'grid');
boxFile=fullfile(matrixPath,'Data','boxes');
profilesFile=fullfile(matrixPath,'Data','profile_data');

load(gridFile,'nx','ny','nz','x','y','z','gridType')

load(profilesFile,'Irr')

Tavg=[1/720:1/12:1-1/720]';
nt=length(Tavg);

trNames={'po4','dop','oxy','phy','zoo','det','no3','dic','alk'};

numTr=length(trNames);

if strcmp(gridType,'llc_v4')
  load(fullfile(base_path,'llc_v4_grid'))
  gcmfaces_global
end

for itr=1:numTr
  varName=upper(trNames{itr})
  fn=[trNames{itr} 'avg.petsc'];
  tr=readPetscBinVec(fn,-1);
  TR=matrixToGrid(tr(Irr,:),[],boxFile,gridFile);

  if strcmp(gridType,'llc_v4')
    error('LLC_v4 not supported!')
%     varName=[varName '_plot'];
% 	tmp=gcmfaces(TR);
% 	[x,y,TRplot]=convert2pcol(mygrid.XC,mygrid.YC,tmp);
% 	[n1,n2]=size(TRplot);
% 	eval([trNames{itr} '=zeros([n1 n2 nz]);']);
% 	for iz=1:nz
% 	  eval(['[x,y,' varName '(:,:,iz)]=convert2pcol(mygrid.XC,mygrid.YC,tmp(:,:,iz));']);
% 	end
  else
	eval([varName '=TR;']);
  end
  save([varName 'mm'],varName,'x','y','z','Tavg')
%   write2netcdf([varName 'mm.nc'],TR,x,y,z,Tavg,upper(varName))
end
