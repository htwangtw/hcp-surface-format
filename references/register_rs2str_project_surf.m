function register_rs2str_project_surf(fs_ID, SUBJECTS_DIR, RS_DIR, RANDNUM, onlysmoothing)

% SUBJECTS_DIR  = '/local_raid/seokjun/01_project/08_Autism_abide/02_file/01_fs_processed/';
% RS_DIR        = '/local_raid/seokjun/01_project/08_Autism_abide/02_file/03_fMRI_preprocessed/Outputs/cpac/filt_noglobal/func_preproc/';

fid = fopen('/local_raid/seokjun/01_project/08_Autism_abide/01_analysis/abide_demo_hong2.csv');
C   = textscan(fid,'%s%s%s','Delimiter',',','headerLines',1,'CollectOutput',1);
ID1 = C{1}(:, 2);
ID2 = C{1}(:, 1);
SITE = C{1}(:, 3);
fclose(fid);

rs_ID = ID2{strcmp(ID1, fs_ID)};
site  = SITE{strcmp(ID1, fs_ID)};

fid = fopen([ '/tmp/' RANDNUM '_case.txt'], 'wt');
fprintf(fid, '%s', rs_ID);
fclose(fid);

if(strcmp(site, 'PITT'))
    
    site = 'Pitt';
    
end
fid = fopen([ '/tmp/' RANDNUM '_site.txt'], 'wt');
fprintf(fid, '%s', site);
fclose(fid);

if(strcmp(onlysmoothing, '0'))
    anatfs_vol = [ SUBJECTS_DIR fs_ID '/mri/brain' ];
    rs_vol     = [ RS_DIR '/' site '_00' rs_ID '_func_preproc.nii.gz' ];
    
    if(~exist([ anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ], 'file'))
        
        % 1) convert mgz to nii.gz and reorient the image
        [r, s] = system([ '/export01/local/freesurfer/bin/mri_convert ' anatfs_vol '.mgz ' anatfs_vol '_nii.nii.gz' ])
        [r, s] = system([ 'fsl5.0-fslreorient2std ' anatfs_vol '_nii.nii.gz ' anatfs_vol '_reo_nii.nii.gz' ])
        
        % 2) linear transformation to MNI152 template
        [r, s] = system([ 'fsl5.0-flirt -in ' anatfs_vol '_reo_nii.nii.gz -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz -out ' anatfs_vol '_reo2MNI_nii.nii.gz -omat ' anatfs_vol '_reo2MNI_nii.mat' ])
        
        % 3) non-linear transformation to MNI152 template
        [r, s] = system([ 'fsl5.0-fnirt --ref=/usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz --in=' anatfs_vol '_reo_nii.nii.gz --aff=' anatfs_vol '_reo2MNI_nii.mat --iout=' anatfs_vol '_reo2MNI_nl_nii.nii.gz --fout=' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ])
        
    end
    
    if(true)
        
        % 4) average two surfaces
        [r, c_ras_str] = system( ['mri_info --cras ' anatfs_vol '_reo_nii.nii.gz' ]);
        c_ras_str = strsplit(c_ras_str);
        
        c_ras = [];
        for i = 1 : length(c_ras_str)
            if(~isempty(c_ras_str{i}))
                c_ras = [ c_ras str2num(c_ras_str{i}) ];
            end
        end
        
        pial        = SurfStatReadSurf1([ SUBJECTS_DIR fs_ID '/surf/lh.pial' ]);
        white       = SurfStatReadSurf1([ SUBJECTS_DIR fs_ID '/surf/lh.white' ]);
        mid.tri     = pial.tri;
        mid.coord   = (pial.coord + white.coord)/2;
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/lh.mid' ], mid);
        mid.coord = mid.coord + repmat(c_ras', 1, size(mid.coord, 2));
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/lh.mid2' ], mid);
        pial.coord = pial.coord + repmat(c_ras', 1, size(pial.coord, 2));
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/lh.pial2' ], pial);
        white.coord = white.coord + repmat(c_ras', 1, size(white.coord, 2));
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/lh.white2' ], white);
        
        pial        = SurfStatReadSurf1([ SUBJECTS_DIR fs_ID '/surf/rh.pial' ]);
        white       = SurfStatReadSurf1([ SUBJECTS_DIR fs_ID '/surf/rh.white' ]);
        mid.tri     = pial.tri;
        mid.coord   = (pial.coord + white.coord)/2;
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/rh.mid' ], mid);
        mid.coord = mid.coord + repmat(c_ras', 1, size(mid.coord, 2));
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/rh.mid2' ], mid);
        pial.coord = pial.coord + repmat(c_ras', 1, size(pial.coord, 2));
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/rh.pial2' ], pial);
        white.coord = white.coord + repmat(c_ras', 1, size(white.coord, 2));
        SurfStatWriteSurf1([ SUBJECTS_DIR fs_ID '/surf/rh.white2' ], white);
        
    end
    
    %if(~exist([ SUBJECTS_DIR fs_ID '/surf/lh.mid.rs_ts.mgh' ], 'file') || ~exist([ SUBJECTS_DIR fs_ID '/surf/rh.mid.rs_ts.mgh' ], 'file'))
    if(true)
        
        % 5) transform surfaces
        %[r, s] = system([ 'fsl5.0-invwarp --ref=' anatfs_vol '_reo_nii.nii.gz --warp=' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz --out=' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz' ]);
        [r, s] = system([ 'mris_convert ' SUBJECTS_DIR fs_ID '/surf/lh.pial2 '  SUBJECTS_DIR fs_ID '/surf/lh.pial.gii' ]);
        [r, s] = system([ 'mris_convert ' SUBJECTS_DIR fs_ID '/surf/rh.pial2 '  SUBJECTS_DIR fs_ID '/surf/rh.pial.gii' ]);
        [r, s] = system([ 'mris_convert ' SUBJECTS_DIR fs_ID '/surf/lh.mid2 '  SUBJECTS_DIR fs_ID '/surf/lh.mid.gii' ]);
        [r, s] = system([ 'mris_convert ' SUBJECTS_DIR fs_ID '/surf/rh.mid2 '  SUBJECTS_DIR fs_ID '/surf/rh.mid.gii' ]);
        [r, s] = system([ 'mris_convert ' SUBJECTS_DIR fs_ID '/surf/lh.white2 '  SUBJECTS_DIR fs_ID '/surf/lh.white.gii' ]);
        [r, s] = system([ 'mris_convert ' SUBJECTS_DIR fs_ID '/surf/rh.white2 '  SUBJECTS_DIR fs_ID '/surf/rh.white.gii' ]);
        [r, s] = system([ '/local_raid/seokjun/03_downloads/workbench/bin_rh_linux64/wb_command -surface-apply-warpfield ' SUBJECTS_DIR fs_ID '/surf/lh.pial.gii ' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz ' SUBJECTS_DIR fs_ID '/surf/lh.pial.MNI.gii -fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ]);
        [r, s] = system([ '/local_raid/seokjun/03_downloads/workbench/bin_rh_linux64/wb_command -surface-apply-warpfield ' SUBJECTS_DIR fs_ID '/surf/rh.pial.gii ' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz ' SUBJECTS_DIR fs_ID '/surf/rh.pial.MNI.gii -fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ]);
        [r, s] = system([ '/local_raid/seokjun/03_downloads/workbench/bin_rh_linux64/wb_command -surface-apply-warpfield ' SUBJECTS_DIR fs_ID '/surf/lh.mid.gii ' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz ' SUBJECTS_DIR fs_ID '/surf/lh.mid.MNI.gii -fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ]);
        [r, s] = system([ '/local_raid/seokjun/03_downloads/workbench/bin_rh_linux64/wb_command -surface-apply-warpfield ' SUBJECTS_DIR fs_ID '/surf/rh.mid.gii ' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz ' SUBJECTS_DIR fs_ID '/surf/rh.mid.MNI.gii -fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ]);
        [r, s] = system([ '/local_raid/seokjun/03_downloads/workbench/bin_rh_linux64/wb_command -surface-apply-warpfield ' SUBJECTS_DIR fs_ID '/surf/lh.white.gii ' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz ' SUBJECTS_DIR fs_ID '/surf/lh.white.MNI.gii -fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ]);
        [r, s] = system([ '/local_raid/seokjun/03_downloads/workbench/bin_rh_linux64/wb_command -surface-apply-warpfield ' SUBJECTS_DIR fs_ID '/surf/rh.white.gii ' anatfs_vol '_MNI2reo_nlwarp_nii.nii.gz ' SUBJECTS_DIR fs_ID '/surf/rh.white.MNI.gii -fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz' ]);
        
    end
    
end
