function [output,info] = int1d(Th,Coef,Test,Trial,Vh,quadOrder)

% e.g. 
% feSpace --> (v1,v2,v3) or (u1,u2,u3) --> { 'P2','P2','P1' }
% vi and ui are in the same FE space

%% ------------------ Preparation for the input ------------------
% default para
if nargin == 3,  Trial = []; Vh = {'P1'}; quadOrder = 3; end 
if nargin == 4,  Vh = {'P1'}; quadOrder = 3; end % default: P1
if nargin == 5, quadOrder = 3; end

if ~iscell(Vh), Vh = {Vh}; end % feSpace = 'P1'    

%% ----------------- extended [Coef,Trial,Test] -------------------
nSpace = length(Vh);
if ~isempty(Trial) && nSpace>1
    [Coef,Test,Trial] = getExtendedvarForm(Coef,Test,Trial);
end

%% --------- Sparse assembling index of Pk-Lagrange element --------
% elementwise d.o.f.s
elem2dofv = cell(1,nSpace); NNdofv = zeros(1,nSpace); 
for i = 1:nSpace
    [elem2dofv{i},~,NNdofv(i)] = dof1d(Th,Vh{i}); % vi    
end
elem2dofu = elem2dofv; NNdofu = NNdofv;
NNdofvv = sum(NNdofv);  NNdofuu = NNdofvv;

info.NNdofu = NNdofu; % 

% assembling index
ii = cell(nSpace^2,1);  jj = ii;  s = 1;
for i = 1:nSpace
    for j = 1:nSpace
        [iiv,jju] = getSparse(elem2dofv{i}, elem2dofu{j});
        ii{s} = iiv + (i>=2)*sum(NNdofv(1:i-1));
        jj{s} = jju + (j>=2)*sum(NNdofu(1:j-1));
        s = s+1;
    end
end

%% ------------------------- Bilinear form -------------------------
if ~isempty(Trial)
    idvu = true(nSpace^2,1);  ss = cell(nSpace^2,1); k = 1;
    % (vi,uj), i,j = 1,...,nSpace
    for i = 1:nSpace
        for j = 1:nSpace
            Vhij = { Vh{i}, Vh{j} }; % FE space pair w.r.t. (vi,uj)
            % ---------- scaler case ----------
            if nSpace==1
               [~, ss{k}] = assem1d(Th,Coef,Test,Trial,Vhij,quadOrder);
               break;
            end
            % ---------- vectorized FEM ----------
            id = mycontains(Test,sprintf('%d',i)) & mycontains(Trial,sprintf('%d',j));
            if ~sum(id)  %  empty
                idvu(k) = false; k = k+1;   continue;
            end
            [~, ss{k}] = assem1d(Th,Coef(id),Test(id),Trial(id),Vhij,quadOrder);
            k = k+1;
        end
    end
    ii = ii(idvu); jj = jj(idvu); ss = ss(idvu);
    ii = vertcat(ii{:});   jj = vertcat(jj{:});  ss = vertcat(ss{:});
    output = sparse(ii,jj,ss,NNdofvv,NNdofuu);
    return;  % The remaining code will be neglected.
end

%% -------------------------- Linear form --------------------------
ff = zeros(NNdofvv,1);

% ---------------- scalar case ---------------
if nSpace==1
    output = assem1d(Th,Coef,Test,Trial,Vh,quadOrder);
    return; % otherwise, vectorized FEM
end

% ---------------- vectorized FEM ---------------
% Test --> v.val = [v1.val, v2.val, v3.val]
if strcmpi(Test, 'v.val')
    trf = eye(nSpace); f = Coef;
    for i = 1:nSpace
        Coef = @(pz) f(pz)*trf(:, i);  Test = sprintf('v%d.val',i);
        Fi = assem1d(Th,Coef,Test,[],Vh{i},quadOrder);
        if i==1, id = 1 : NNdofv(1);  end
        if i>=2, id = NNdofv(i-1) + (1:NNdofv(i)); end
        ff(id) = ff(id) + Fi;
    end
    output = ff;  return;
end

% Test -->  'v1.val' --> {'v1.val'} 
if ~iscell(Test), Coef = {Coef};  Test = {Test}; end

% Test --> {'v1.val', 'v3.val'}
for s = 1:length(Test)
    Coefv = Coef{s}; Testv = Test{s};
    for i = 1:nSpace
        str = sprintf('v%d.val',i);  % vi.val
        if strcmpi(Testv, str)
            Fi = assem1d(Th,Coefv,Testv,[],Vh{i},quadOrder);
            if i==1, id = 1 : NNdofv(1);  end
            if i>=2, id = NNdofv(i-1) + (1:NNdofv(i)); end
            ff(id) = ff(id) + Fi;
        end
    end
end
output = ff;