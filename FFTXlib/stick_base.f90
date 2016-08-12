!
! Copyright (C) Quantum ESPRESSO group
!
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!=----------------------------------------------------------------------=
   MODULE block_distro
!=----------------------------------------------------------------------=

!  ... Added by Eric Pascolo


   IMPLICIT NONE
   PRIVATE
   SAVE

   PUBLIC :: map_blocks, find_max,write_matrix_strange_idx

!=----------------------------------------------------------------------=
   CONTAINS
!=----------------------------------------------------------------------=


SUBROUTINE map_blocks(maps,row_w,col_w,ub,lb,myid,num_of_core)

  IMPLICIT NONE
  INTEGER, INTENT(in) :: ub(3),lb(3),row_w,col_w,myid,num_of_core
  INTEGER, INTENT(inout) :: maps( lb(1): ub(1), lb(2):ub(2) )
  INTEGER :: i,nprow,npcol
  INTEGER :: row_el,col_el,block_num
  INTEGER, ALLOCATABLE :: proc_idx_matrix(:,:)
  
! GENERAZIONE DIMENSIONI BLOCCHI
  CALL set_block(nprow,npcol,num_of_core)
  
! GENERAZIONE INFO BLOCCHI
  CALL get_info_block(row_w,col_w,nprow,npcol,row_el,col_el,block_num)

 
!  WRITE(6,*) '  PARAMETRI DISTRIBUZIONE G scalapack like'
!  WRITE(6,*) '  -----------------------------------------'
!  WRITE(6,*) '  Number of CORE', num_of_core
!  WRITE(6,*) '  Number of ROW', ub(1)-lb(1)
!  WRITE(6,*) '  Number of ROW wave', row_w
!  WRITE(6,*) '  Number of COL', ub(2)-lb(2)
!  WRITE(6,*) '  Number of COL wave', col_w
!  WRITE(6,*) '  Number of core/ROW', nprow
!  WRITE(6,*) '  Number of core/COL', npcol
!  WRITE(6,*) '  SIZE ROW block', row_el
!  WRITE(6,*) '  SIZE COL block', col_el
!  WRITE(6,*) '  NUMBER OF BLOCK', block_num
!  WRITE(6,*) '  -----------------------------------------'

  ALLOCATE(proc_idx_matrix(nprow,npcol))
  
  proc_idx_matrix = 0
  maps = 0
        
! GENERAZIONE MATRICE PER DISTRIBUZIONE PROCESSORI 
  CALL set_matrix_processor(nprow,npcol,proc_idx_matrix)
  
! SCRITTURA SU FILE MATRICE PER DISTRIBUZIONE PROCESSORI
!  IF(myid .eq. 0) CALL write_matrix(proc_idx_matrix,nprow,npcol,"./mappe/pattern_proc.matrix")
  
! GENERAZIONE MATRICE MAPPA 
  CALL distro_matrix_processor(ub,lb,nprow,npcol,row_el,col_el,proc_idx_matrix,maps)
  
!  IF(myid .eq. 0) CALL write_matrix_strange_idx(maps,ub,lb,"./mappe/mappa_core_scalike.matrix")
    
  DEALLOCATE(proc_idx_matrix)
    
END SUBROUTINE map_blocks

!=----------------------------------------------------------------------=

SUBROUTINE set_block(npr,npc,num_of_core)
! GENERAZIONE DIMENSIONI BLOCCHI
  IMPLICIT NONE
  INTEGER, INTENT(in) :: num_of_core
  INTEGER, INTENT(inout) :: npr,npc
  INTEGER :: i,sqrtnp

  sqrtnp = INT( SQRT( REAL( num_of_core ) + 0.1 ) )
  
  DO i = 1, sqrtnp + 1
    IF( MOD( num_of_core, i ) == 0 ) npr = i
  ENDDO

  npc = num_of_core / npr

END SUBROUTINE set_block

!=----------------------------------------------------------------------=

SUBROUTINE get_info_block(row,col,npr,npc,elpr,elpc,epb)
! CALCOLO INFO BLOCCHI
  IMPLICIT NONE
  INTEGER, INTENT(in) :: row,col
  INTEGER, INTENT(in) :: npr,npc
  INTEGER, INTENT(out) :: elpr,elpc,epb
  INTEGER :: i,sqrtnp
  
  elpr = (row/npr);
  elpc = (col/npc);
  epb =  ((row*col)/(2*elpr*elpc));
  
END SUBROUTINE get_info_block

!=----------------------------------------------------------------------=

SUBROUTINE set_matrix_processor(npr,npc,pmatrix)
! GENERAZIONE MATRICE PROCESSORI
  IMPLICIT NONE
  INTEGER, INTENT(in) :: npr,npc
  INTEGER, INTENT(out) :: pmatrix(:,:)
  INTEGER :: i,j,p,row,col
  
  p = 1
  DO i=1,npc
    DO j=1,npr
        pmatrix(j,i) = p
        p= p+1
    ENDDO
  ENDDO    
  
  
END SUBROUTINE set_matrix_processor

!=----------------------------------------------------------------------=

SUBROUTINE distro_matrix_processor(ub,lb,npr,npc,elpr,elpc,pmatrix,proc_distro_matrix)

! DISTRO

  IMPLICIT NONE
  INTEGER, INTENT(in) :: npr,npc,elpr,elpc,ub(3),lb(3)
  INTEGER, INTENT(in) :: pmatrix(npr,npc)
  INTEGER, INTENT(inout) :: proc_distro_matrix(lb(1): ub(1), lb(2):ub(2))
  INTEGER :: i,j,i0,j0,i0b,j0b,ib,jb,jb1,row,col
  proc_distro_matrix = 0
  ib = 0
  jb = 0
  row = ub(1)
  col = ub(2)
  
!   RIEMPIMENTO CENTRO RIGHT
  DO i=elpr,row,elpr
    
    ib = MOD(ib,npr)+1;
    i0=i - elpr;
    jb = 0
    DO j=elpc,col,elpc
           
      j0=j - elpc;
      jb = MOD(jb,npc)+1;
      
      proc_distro_matrix(i0:i,j0:j) = pmatrix(ib,jb); 
      j0b = j
    ENDDO
    i0b = i
  ENDDO

     
  ib = 0
  
!   RIEMPIMENTO BORDO RIGHT LATERALE
  DO i=0,row
  
      proc_distro_matrix(i,j0b:col) = proc_distro_matrix(i,j0b-1) 
        
  ENDDO
    
!   RIEMPIMENTO BORDO RIGHT SOPRA
  DO j=0,col
      proc_distro_matrix(i0b:row,j) =  proc_distro_matrix(i0b-1,j);
  ENDDO
  
  !RIEMPIMENTO CENTRO LEFT
  ib = 0
  row = ub(1)
  col = lb(2)

  DO i=elpr,row,elpr
    
    ib = MOD(ib,npr)+1;
    jb1 = 0
    DO j=-elpc-1,col,-elpc
       
      i0=i - elpr;
      j0=j + elpc;
      jb = npc - MOD(jb1,npc);
      proc_distro_matrix(i0:i,j:j0) = pmatrix(ib,jb);
      jb1 = jb1+1
      j0b = j

    ENDDO
    
    i0b = i
    
  ENDDO
  
  ib = 2
  
  !RIEMPIMENTO BORDO LEFT LATERALE
  DO i=0,row
      proc_distro_matrix(i,col:j0b) = proc_distro_matrix(i,j0b+1) 
  ENDDO
    
  !RIEMPIMENTO BORDO LEFT SOTTO
  DO j=-1,col,-1
      proc_distro_matrix(i0b:ub(1),j) =  proc_distro_matrix(i0b-1,j);
  ENDDO
  
  
END SUBROUTINE distro_matrix_processor

!=----------------------------------------------------------------------=

SUBROUTINE find_max(ub,lb,mtw,row,col,my,ncore)

  INTEGER,INTENT(OUT) :: row,col
  INTEGER,INTENT(IN)  :: ub(:),lb(:),mtw(lb(1):ub(1),lb(2):ub(2))
  INTEGER,INTENT(IN)  :: my,ncore
  INTEGER :: i,j,max_proc,vector(0:ub(2)),ncr,ncc
  
  CALL set_block(ncr,ncc,ncore)
  vector = 0
  max_proc = max(ncr,ncc)
  
  WRITE(6,*) 'max proc',max_proc,'ncr',ncr,'ncc',ncc
  WRITE(6,*) 'ub1',ub(1),'ub2',ub(2)
  
  DO j=0,ub(2)
  
    DO i=0,ub(1)
    
    IF (mtw(i,j).ne. 0)THEN
      vector(j) = i
    ELSE
      EXIT
    ENDIF
    
    ENDDO
        
  ENDDO
  
  
  IF(my .eq. 1) WRITE(*,*) 'vector',vector(:)
  
  
  DO i=0,ub(2)
  
     IF( abs(i-vector(i)) .le. 1 .AND. i>max_proc .AND. vector(i)>max_proc ) THEN
     row = vector(i)
     col = i
     EXIT
     
     ENDIF
  
  ENDDO
  
 
  
END SUBROUTINE

!=----------------------------------------------------------------------=

SUBROUTINE write_matrix(mtw,righe,colonne,percorso)

    IMPLICIT NONE
    INTEGER :: i, j, righe,colonne
    character(LEN=*), INTENT(in) :: percorso
    INTEGER, INTENT(in) :: mtw(righe,colonne)
    
    OPEN(unit=115, file=percorso)
    DO i=1,righe
       WRITE(115,'(1000I6)') mtw(i,1:colonne)
    END DO
    CLOSE(115)

END SUBROUTINE write_matrix

!=----------------------------------------------------------------------=

SUBROUTINE write_matrix_strange_idx(mtw,ub,lb,percorso)

  IMPLICIT NONE
  INTEGER :: i, j, ub(3),lb(3)
  character(LEN=*), INTENT(in) :: percorso
  INTEGER, INTENT(in) :: mtw(lb(1):ub(1),lb(2):ub(2))
    
  OPEN(unit=116, file=percorso)

    DO i=ub(1),lb(1),-1
       WRITE(116,'(1000I6)') mtw(i,lb(2):ub(2))
    END DO
    
  CLOSE(116)

END SUBROUTINE write_matrix_strange_idx

!=----------------------------------------------------------------------=
   END MODULE block_distro
!=----------------------------------------------------------------------=


!=----------------------------------------------------------------------=
   MODULE stick_base
!=----------------------------------------------------------------------=

        IMPLICIT NONE
        PRIVATE
        SAVE

#if defined(__MPI)
        INCLUDE 'mpif.h'
#endif

        INTEGER, PARAMETER :: DP = selected_real_kind(14,200)

        PUBLIC :: sticks_map_set, sticks_countg, sticks_dist, sticks_pairup
        PUBLIC :: sticks_owner, sticks_deallocate, sticks_ordered_dist
        PUBLIC :: sticks_map_index, sticks_sort_new, sticks_dist_new
        PUBLIC :: sticks_set_owner, sticks_map, sticks_map_allocate
        PUBLIC :: sticks_map_deallocate

        TYPE sticks_map
           LOGICAL :: lgamma=.false. ! true = the map has gamma symmetry
           LOGICAL :: lpara=.false.  ! true = the map is set for parallel and serial, false = only serial 
           INTEGER :: mype=0   ! my task id (starting from 0)
           INTEGER :: nproc=1  ! number of task
#ifdef __MPI
           INTEGER :: comm     = MPI_COMM_NULL
#else
           INTEGER :: comm     = 0          ! communicator of the fft gruop 
#endif
           INTEGER :: nstx=0   ! a safe maximum number of sticks on the map
           INTEGER :: lb(3)=0  ! map's lower bounds
           INTEGER :: ub(3)=0  ! map's upper bounds
           INTEGER, ALLOCATABLE :: idx(:)   ! the index of each stick
           INTEGER, ALLOCATABLE :: ist(:,:) ! the cartesian coordinates of each stick
           INTEGER, ALLOCATABLE :: stown(:,:) ! the owner of each stick
           INTEGER, ALLOCATABLE :: indmap(:,:) ! the index of each stick (represented on the map)
           REAL(DP) :: bg(3,3) ! base vectors, the generators of the mapped space
        END TYPE

! ...   sticks_owner :   stick owner, sticks_owner( i, j ) is the index of the processor
! ...     (starting from 1) owning the stick whose x and y coordinate  are i and j.

        INTEGER, ALLOCATABLE, TARGET :: sticks_owner( : , : )


!=----------------------------------------------------------------------=
   CONTAINS
!=----------------------------------------------------------------------=

  SUBROUTINE sticks_map_deallocate( smap )
     TYPE( sticks_map ) :: smap
     IF( ALLOCATED( smap%idx ) ) DEALLOCATE( smap%idx )
     IF( ALLOCATED( smap%ist ) ) DEALLOCATE( smap%ist )
     IF( ALLOCATED( smap%stown ) ) DEALLOCATE( smap%stown )
     IF( ALLOCATED( smap%indmap ) ) DEALLOCATE( smap%indmap )
     smap%ub = 0
     smap%lb = 0
     smap%nstx = 0
  END SUBROUTINE sticks_map_deallocate

  SUBROUTINE sticks_map_allocate( smap, lgamma, lpara, nr1, nr2, nr3, bg, comm )
     TYPE( sticks_map ) :: smap
     LOGICAL, INTENT(IN) :: lgamma
     LOGICAL, INTENT(IN) :: lpara
     INTEGER, INTENT(IN) :: nr1, nr2, nr3
     INTEGER, INTENT(IN) :: comm
     REAL(DP), INTENT(IN) :: bg(3,3)
     INTEGER :: lb(3), ub(3)
     INTEGER :: nstx, ierr
     ub(1) = ( nr1 - 1 ) / 2
     ub(2) = ( nr2 - 1 ) / 2
     ub(3) = ( nr3 - 1 ) / 2
     lb    = - ub
     nstx = (ub(1)-lb(1)+1)*(ub(2)-lb(2)+1) ! we stay very large indeed
     IF( smap%nstx == 0 ) THEN
        ! this map is clean, allocate
        smap%mype = 0
        smap%nproc = 1
        smap%comm = comm
#ifdef __MPI
        CALL MPI_COMM_RANK( smap%comm, smap%mype, ierr )
        CALL MPI_COMM_SIZE( smap%comm, smap%nproc, ierr )
#endif
        smap%lgamma = lgamma
        smap%lpara = lpara
        smap%comm = comm
        smap%nstx = nstx
        smap%ub = ub
        smap%lb = lb
        smap%bg = bg
        ALLOCATE( smap%indmap ( lb(1):ub(1), lb(2):ub(2) ) )
        ALLOCATE( smap%stown ( lb(1):ub(1), lb(2):ub(2) ) )
        ALLOCATE( smap%idx( nstx ) )
        ALLOCATE( smap%ist( nstx , 2) )
        smap%stown = 0
        smap%indmap = 0
        smap%idx = 0
        smap%ist = 0
     ELSE IF( smap%nstx < nstx ) THEN
        ! map resizing, re-allocate
         CALL fftx_error__(' sticks_map_allocate ',' sticks map resizing, not yet implemented ', 1 )
     END IF
     RETURN
  END SUBROUTINE

  SUBROUTINE sticks_map_set( lgamma, ub, lb, bg, gcut, st, comm )

    ! .. Compute the basic maps of sticks
    ! .. st(i,j) will contain the number of G vectors of the stick whose indices are (i,j).

    LOGICAL, INTENT(in) :: lgamma !  if true use gamma point simmetry
    INTEGER, INTENT(in) :: ub(:)  !  upper bounds for i-th grid dimension
    INTEGER, INTENT(in) :: lb(:)  !  lower bounds for i-th grid dimension
    REAL(DP) , INTENT(in) :: bg(:,:) ! reciprocal space base vectors
    REAL(DP) , INTENT(in) :: gcut  ! cut-off for potentials
    INTEGER, OPTIONAL, INTENT(in) :: comm ! communicator of the g-vec group
    !
#if defined(__MPI)
    INCLUDE 'mpif.h'
#endif
    !
    !     stick map for wave functions, note that map is taken in YZ plane
    !
    INTEGER, INTENT(out) :: st( lb(1) : ub(1), lb(2) : ub(2) )
    REAL(DP) :: b1(3), b2(3), b3(3) 
    INTEGER :: i1, i2, i3, n1, n2, n3, mype, nproc, ierr
    REAL(DP) :: amod

    st = 0
    b1(:) = bg(:,1)
    b2(:) = bg(:,2)
    b3(:) = bg(:,3)

    n1 = max( abs( lb(1) ), abs( ub(1) ) )
    n2 = max( abs( lb(2) ), abs( ub(2) ) )
    n3 = max( abs( lb(3) ), abs( ub(3) ) )

    mype = 0
    nproc = 1
#ifdef __MPI
    IF( PRESENT( comm ) ) THEN
       CALL MPI_COMM_RANK( comm, mype, ierr )
       CALL MPI_COMM_SIZE( comm, nproc, ierr )
    END IF
#endif

    loop1: DO i1 = - n1, n1
       !
       ! Gamma-only: exclude space with x<0
       !
       IF ( (lgamma .and. i1 < 0) .OR. ( MOD( i1 + n1, nproc ) /= mype )) CYCLE loop1
       !
       loop2: DO i2 = - n2, n2
          !
          ! Gamma-only: exclude plane with x=0, y<0
          !
          IF(lgamma .and. i1 == 0.and. i2 < 0) CYCLE loop2
          !
          loop3: DO i3 = - n3, n3
             !
             ! Gamma-only: exclude line with x=0, y=0, z<0
             !
             IF(lgamma .and. i1 == 0 .and. i2 == 0 .and. i3 < 0) CYCLE loop3
             !
             amod = (i1 * b1 (1) + i2 * b2 (1) + i3 * b3 (1) ) **2 + &
                    (i1 * b1 (2) + i2 * b2 (2) + i3 * b3 (2) ) **2 + &
                    (i1 * b1 (3) + i2 * b2 (3) + i3 * b3 (3) ) **2
             IF (amod <= gcut ) THEN
                st( i1, i2 ) = st( i1, i2 ) + 1
             ENDIF
          ENDDO loop3
       ENDDO loop2
    ENDDO loop1

#if defined(__MPI)
    IF( PRESENT( comm ) ) THEN
       CALL MPI_ALLREDUCE(MPI_IN_PLACE, st, size(st), MPI_INTEGER, MPI_SUM, comm, ierr)
    END IF
#endif

    RETURN
  END SUBROUTINE sticks_map_set

!=----------------------------------------------------------------------=

    SUBROUTINE sticks_map_index( ub, lb, st, in1, in2, ngc, index_map )

      INTEGER, INTENT(in) :: ub(:), lb(:)
      INTEGER, INTENT(in) :: st( lb(1): ub(1), lb(2):ub(2) ) ! stick map for potential
      INTEGER, INTENT(inout) :: index_map( lb(1): ub(1), lb(2):ub(2) ) ! keep track of sticks index

      INTEGER, INTENT(out) :: in1(:), in2(:)
      INTEGER, INTENT(out) :: ngc(:)

      INTEGER :: j1, j2, i1, i2, i3, nct, min_size, ind
      LOGICAL :: ok

!
! ...     initialize the sticks indexes array ist
! ...     nct counts columns containing G-vectors for the dense grid
! ...     ncts counts columns contaning G-vectors for the smooth grid
!
      nct   = MAXVAL( index_map )
      ngc   = 0

      min_size = min( size( in1 ), size( in2 ), size( ngc ) )

      DO j2 = 0, ( ub(2) - lb(2) )
        DO j1 = 0, ( ub(1) - lb(1) )
          i1 = j1
          IF( i1 > ub(1) ) i1 = lb(1) + ( i1 - ub(1) ) - 1
          i2 = j2
          IF( i2 > ub(2) ) i2 = lb(2) + ( i2 - ub(2) ) - 1
          IF( st( i1, i2 ) > 0 ) THEN
            IF( index_map( i1, i2 ) == 0 ) THEN
              nct = nct + 1
              index_map( i1, i2 ) = nct
            END IF
            ind = index_map( i1, i2 )
            IF( nct > min_size ) &
              CALL fftx_error__(' sticks_map_index ',' too many sticks ', nct )
            in1(ind) = i1
            in2(ind) = i2
            ngc(ind) = st( i1 , i2)
          ENDIF
        ENDDO
      ENDDO

      RETURN
    END SUBROUTINE sticks_map_index

!=----------------------------------------------------------------------=

      SUBROUTINE sticks_sort_new( parallel, ng, nct, idx )

! ...     This subroutine sorts the sticks indexes, according to
! ...     the length and type of the sticks, wave functions sticks
! ...     first, then smooth mesh sticks, and finally potential
! ...     sticks

        ! lengths of sticks, ngc for potential mesh, ngcw for wave functions mesh
        ! and ngcs for smooth mesh

        LOGICAL, INTENT(in) :: parallel
        INTEGER, INTENT(in) :: ng(:)

        ! nct, total number of sticks

        INTEGER, INTENT(in) :: nct

        ! index, on output, new sticks indexes

        INTEGER, INTENT(inout) :: idx(:)

        INTEGER  :: mc, ic, nc
        INTEGER, ALLOCATABLE :: iaux(:)
        INTEGER, ALLOCATABLE :: itmp(:)
        REAL(DP), ALLOCATABLE :: aux(:)

        !  we need to avoid sorting elements already sorted previously
        !  build inverse indexes
        ALLOCATE( iaux( nct ) )
        iaux = 0
        DO mc = 1, nct
          IF( idx( mc ) > 0 ) iaux( idx( mc ) ) = mc
        END DO
        !
        !  check idx has no "hole"
        !
        IF( idx( 1 ) == 0 ) THEN
          ic = 0
          DO mc = 2, nct
            IF( idx( mc ) /= 0 ) THEN
              CALL fftx_error__(' sticks_sort ',' non contiguous indexes 1 ', nct )
            END IF
          END DO
        ELSE
          ic = 1
          DO mc = 2, nct
            IF( idx( mc ) == 0 ) EXIT 
            ic = ic + 1
          END DO
          DO mc = ic+1, nct
            IF( idx( mc ) /= 0 ) THEN
              CALL fftx_error__(' sticks_sort ',' non contiguous indexes 2 ', nct )
            END IF
          END DO
        END IF

        IF( parallel ) THEN
          ALLOCATE( aux( nct ) )
          ALLOCATE( itmp( nct ) )
          itmp = 0
          nc = 0
          DO mc = 1, nct
            IF( ng( mc ) > 0 .AND. iaux( mc ) == 0 ) THEN
              nc = nc + 1
              aux( nc ) = -ng(mc) 
              itmp( nc ) = mc
            END IF
          ENDDO
          CALL hpsort( nc, aux, itmp)
          DO mc = 1, nc
             idx( ic + mc ) = itmp( mc )
          END DO
          DEALLOCATE( itmp )
          DEALLOCATE( aux )
        ELSE
          DO mc = 1, nct
            IF( ng(mc) > 0 .AND. iaux(mc) == 0 ) THEN
              ic = ic + 1
              idx(ic) = mc
            ENDIF
          ENDDO
        ENDIF

        DEALLOCATE( iaux )

        RETURN
      END SUBROUTINE sticks_sort_new


      SUBROUTINE sticks_sort( ngc, ngcw, ngcs, nct, idx, nproc )

! ...     This subroutine sorts the sticks indexes, according to
! ...     the length and type of the sticks, wave functions sticks
! ...     first, then smooth mesh sticks, and finally potential
! ...     sticks

        ! lengths of sticks, ngc for potential mesh, ngcw for wave functions mesh
        ! and ngcs for smooth mesh

        INTEGER, INTENT(in) :: ngc(:), ngcw(:), ngcs(:)
        INTEGER, INTENT(in) :: nproc ! number of proc in the g-vec group

        ! nct, total number of sticks

        INTEGER, INTENT(in) :: nct

        ! index, on output, new sticks indexes

        INTEGER, INTENT(out) :: idx(:)

        INTEGER  :: mc, nr3x, ic
        REAL(DP) :: dn3
        REAL(DP), ALLOCATABLE :: aux(:)

        nr3x = maxval( ngc(1:nct) ) + 1
        dn3  = REAL( nr3x )

        IF( nproc > 1 ) THEN
          ALLOCATE( aux( nct ) )
          DO mc = 1, nct
            aux(mc) = ngcw(mc)
            aux(mc) = dn3 * aux(mc) + ngcs(mc)
            aux(mc) = dn3 * aux(mc) + ngc(mc)
            aux(mc) = -aux(mc)
            idx(mc) = 0
          ENDDO
          CALL hpsort( nct, aux, idx)
          DEALLOCATE( aux )
        ELSE
          ic = 0
          DO mc = 1, nct
            IF( ngcw(mc) > 0 ) THEN
              ic = ic + 1
              idx(ic) = mc
            ENDIF
          ENDDO
          DO mc = 1, nct
            IF( ngcs(mc) > 0 .and. ngcw(mc) == 0 ) THEN
              ic = ic + 1
              idx(ic) = mc
            ENDIF
          ENDDO
          DO mc = 1, nct
            IF( ngc(mc) > 0 .and. ngcs(mc) == 0 .and. ngcw(mc) == 0 ) THEN
              ic = ic + 1
              idx(ic) = mc
            ENDIF
          ENDDO
        ENDIF
        RETURN
      END SUBROUTINE sticks_sort

!=----------------------------------------------------------------------=

    SUBROUTINE sticks_countg( tk, ub, lb, st, stw, sts, in1, in2, ngc, ngcw, ngcs )

      INTEGER, INTENT(in) :: ub(:), lb(:)
      INTEGER, INTENT(in) :: st( lb(1): ub(1), lb(2):ub(2) ) ! stick map for potential
      INTEGER, INTENT(in) :: stw(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions
      INTEGER, INTENT(in) :: sts(lb(1): ub(1), lb(2):ub(2) ) ! stick map for smooth mesh
      LOGICAL, INTENT(in) :: tk

      INTEGER, INTENT(out) :: in1(:), in2(:)
      INTEGER, INTENT(out) :: ngc(:), ngcw(:), ngcs(:)

      INTEGER :: j1, j2, i1, i2, nct, min_size

!
! ...     initialize the sticks indexes array ist
! ...     nct counts columns containing G-vectors for the dense grid
! ...     ncts counts columns contaning G-vectors for the smooth grid
!
      nct   = 0

      ngc   = 0
      ngcs  = 0
      ngcw  = 0

      min_size = min( size( in1 ), size( in2 ), size( ngc ), size( ngcw ), size( ngcs ) )

      DO j2 = 0, ( ub(2) - lb(2) )
        DO j1 = 0, ( ub(1) - lb(1) )

          i1 = j1
          IF( i1 > ub(1) ) i1 = lb(1) + ( i1 - ub(1) ) - 1

          i2 = j2
          IF( i2 > ub(2) ) i2 = lb(2) + ( i2 - ub(2) ) - 1

          IF( st( i1, i2 ) > 0 ) THEN

            ! this sticks contains G-vectors

            nct = nct + 1
            IF( nct > min_size ) &
              CALL fftx_error__(' sticks_countg ',' too many sticks ', nct )

            in1(nct) = i1
            in2(nct) = i2

            ngc(nct) = st( i1 , i2)
            IF( stw( i1, i2 ) > 0 ) ngcw(nct) = stw( i1 , i2)
            IF( sts( i1, i2 ) > 0 ) ngcs(nct) = sts( i1 , i2)

          ENDIF

          ! WRITE(7,fmt="(5I5)") i1, i2, nct, ngc(nct), ngcw( nct )

        ENDDO
      ENDDO

      RETURN
    END SUBROUTINE sticks_countg


!=----------------------------------------------------------------------=

    SUBROUTINE sticks_dist_new( lgamma, mype, nproc, ub, lb, idx, in1, in2, ngc, nct, ncp, ngp, stown, ng )

      LOGICAL, INTENT(in) :: lgamma
      INTEGER, INTENT(in) :: mype
      INTEGER, INTENT(in) :: nproc

      INTEGER, INTENT(in) :: ub(:), lb(:), idx(:)
      INTEGER, INTENT(inout) :: stown(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions
      INTEGER, INTENT(in) :: in1(:), in2(:)
      INTEGER, INTENT(in) :: ngc(:)
      INTEGER, INTENT(in) :: nct
      INTEGER, INTENT(out) :: ncp(:)
      INTEGER, INTENT(out) :: ngp(:)
      INTEGER, INTENT(out) :: ng

      INTEGER :: mc, i1, i2, j, jj, icnt

      ncp = 0
      ngp = 0
      icnt = 0

      DO mc = 1, nct

         if( idx( mc ) < 1 ) CYCLE

         i1 = in1( idx( mc ) )
         i2 = in2( idx( mc ) )
!
         IF ( lgamma .and. ( (i1 < 0) .or. ( (i1 == 0) .and. (i2 < 0) ) ) ) GOTO 30
!
         jj = 1
         IF ( ngc( idx(mc) ) > 0 .AND. stown(i1,i2) == 0 ) THEN
            !jj = MOD( icnt, nproc ) + 1
            !icnt = icnt + 1
            DO j = 1, nproc
               IF ( ngp(j) < ngp(jj) ) THEN
                 jj = j
               ELSEIF ( ( ngp(j) == ngp(jj) ) .and. ( ncp(j) < ncp(jj) ) ) THEN
                 jj = j
               ENDIF
            ENDDO
            stown(i1,i2) = jj
         END IF
         IF ( ngc( idx(mc) ) > 0 ) THEN
            ncp( stown(i1,i2) ) = ncp( stown(i1,i2) ) + 1
            ngp( stown(i1,i2) ) = ngp( stown(i1,i2) ) + ngc( idx(mc) )
         ENDIF
 30      CONTINUE
      ENDDO
      !
      ng = ngp( mype + 1 )
      !
      IF ( lgamma ) THEN
        !  when gamma symmetry is used only the sticks of half reciprocal space
        !  are generated, then here we pair-up the sticks with those of the other
        !  half of the space, using the gamma symmetry relation
        !  Note that the total numero of stick "nct" is not modified
        DO mc = 1, nct
           IF( idx( mc ) < 1 ) CYCLE
           IF( ngc( idx(mc) ) < 1 ) CYCLE
           i1 = in1( idx(mc) )
           i2 = in2( idx(mc) )
           IF( i1 == 0 .and. i2 == 0 ) THEN
             jj = stown( i1, i2 )
             IF( jj > 0 ) ngp( jj ) = ngp( jj ) + ngc( idx(mc) ) - 1
           ELSE
             jj = stown( i1, i2 )
             IF( jj > 0 ) THEN
               stown( -i1, -i2 ) = jj
               ncp( jj ) = ncp( jj ) + 1
               ngp( jj ) = ngp( jj ) + ngc( idx(mc) )
             ENDIF
           ENDIF
        ENDDO
      ENDIF

      RETURN
    END SUBROUTINE sticks_dist_new


    SUBROUTINE sticks_dist( tk, ub, lb, idx, in1, in2, ngc, ngcw, ngcs, nct, &
                            ncp, ncpw, ncps, ngp, ngpw, ngps, stown, stownw, stowns, mype, nproc )
#ifdef __NEW_DISTRO
      USE block_distro
#endif

      LOGICAL, INTENT(in) :: tk

      INTEGER, INTENT(in) :: ub(:), lb(:), idx(:)
      INTEGER, INTENT(out) :: stown( lb(1): ub(1), lb(2):ub(2) ) ! stick map for potential
#ifdef __NEW_DISTRO
      INTEGER, INTENT(inout) :: stownw(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions
#else
      INTEGER, INTENT(out) :: stownw(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions
#endif
      INTEGER, INTENT(out) :: stowns(lb(1): ub(1), lb(2):ub(2) ) ! stick map for smooth mesh

      INTEGER, INTENT(in) :: in1(:), in2(:)
      INTEGER, INTENT(in) :: ngc(:), ngcw(:), ngcs(:)
      INTEGER, INTENT(in) :: nct
      INTEGER, INTENT(out) :: ncp(:), ncpw(:), ncps(:)
      INTEGER, INTENT(out) :: ngp(:), ngpw(:), ngps(:)
      INTEGER, INTENT(in) :: mype  ! my proc id in the g-vec group
      INTEGER, INTENT(in) :: nproc ! number of proc in the g-vec group

      INTEGER, ALLOCATABLE :: maps(:,:) ! maps

      INTEGER :: mc, i1, i2, i, j, jj, icnt, rw, cl

      ncp  = 0
      ncps = 0
      ncpw = 0
      ngp  = 0
      ngps = 0
      ngpw = 0

      stown  = 0
#if ! defined __NEW_DISTRO
      stownw = 0
#endif
      stowns = 0

      icnt = 0

#ifdef __NEW_DISTRO

      ALLOCATE(maps(lb(1): ub(1), lb(2):ub(2) ))

      CALL find_max(ub,lb,stownw,rw,cl,mype+1,nproc)

      CALL map_blocks(maps,rw,cl,ub,lb,mype+1,nproc)

      DO mc = 1, nct

         i = idx( mc )

         i1 = in1( i )
         i2 = in2( i )

         IF ( ( .not. tk ) .and. ( (i1 < 0) .or. ( (i1 == 0) .and. (i2 < 0) ) )) GOTO 31

         jj = maps(i1,i2)

         ncp(jj) = ncp(jj) + 1
         ngp(jj) = ngp(jj) + ngc(i)
         stown(i1,i2) = jj

         ! smooth mesh

         IF ( ngcs(i) > 0 ) THEN
            ncps(jj) = ncps(jj) + 1
            ngps(jj) = ngps(jj) + ngcs(i)
            stowns(i1,i2) = jj
         ENDIF

         ! wave functions mesh

         IF ( ngcw(i) > 0 ) THEN
            ncpw(jj) = ncpw(jj) + 1
            ngpw(jj) = ngpw(jj) + ngcw(i)
            stownw(i1,i2) = jj
         ENDIF

 31      CONTINUE

      ENDDO

      DEALLOCATE(maps)

#else


      DO mc = 1, nct

         i = idx( mc )
!
! index contains the desired ordering of sticks (see above)
!
         i1 = in1( i )
         i2 = in2( i )
!
         IF ( ( .not. tk ) .and. ( (i1 < 0) .or. ( (i1 == 0) .and. (i2 < 0) ) ) ) GOTO 30
!
         jj = 1

         IF ( ngcw(i) > 0 ) THEN
!
! this is an active sticks: find which processor has currently
! the smallest number of plane waves
!
            !jj = MOD( icnt, nproc ) + 1
            !icnt = icnt + 1

            DO j = 1, nproc
               IF ( ngpw(j) < ngpw(jj) ) THEN
                 jj = j
               ELSEIF ( ( ngpw(j) == ngpw(jj) ) .and. ( ncpw(j) < ncpw(jj) ) ) THEN
                 jj = j
               ENDIF
            ENDDO

         ELSE
!
! this is an inactive sticks: find which processor has currently
! the smallest number of G-vectors
!
            DO j = 1, nproc
               IF ( ngp(j) < ngp(jj) ) jj = j
            ENDDO

         ENDIF
!
         ! potential mesh

         ncp(jj) = ncp(jj) + 1
         ngp(jj) = ngp(jj) + ngc(i)
         stown(i1,i2) = jj

         ! smooth mesh

         IF ( ngcs(i) > 0 ) THEN
            ncps(jj) = ncps(jj) + 1
            ngps(jj) = ngps(jj) + ngcs(i)
            stowns(i1,i2) = jj
         ENDIF

         ! wave functions mesh

         IF ( ngcw(i) > 0 ) THEN
            ncpw(jj) = ncpw(jj) + 1
            ngpw(jj) = ngpw(jj) + ngcw(i)
            stownw(i1,i2) = jj
         ENDIF

 30      CONTINUE

      ENDDO

#endif

      RETURN
    END SUBROUTINE sticks_dist


!=----------------------------------------------------------------------=


    SUBROUTINE sticks_pairup( tk, ub, lb, idx, in1, in2, ngc, ngcw, ngcs, nct, &
                             ncp, ncpw, ncps, ngp, ngpw, ngps, stown, stownw, stowns, nproc )

      LOGICAL, INTENT(in) :: tk

      INTEGER, INTENT(in) :: ub(:), lb(:), idx(:)
      INTEGER, INTENT(inout) :: stown( lb(1): ub(1), lb(2):ub(2) ) ! stick map for potential
      INTEGER, INTENT(inout) :: stownw(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions
      INTEGER, INTENT(inout) :: stowns(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions

      INTEGER, INTENT(in) :: in1(:), in2(:)
      INTEGER, INTENT(in) :: ngc(:), ngcw(:), ngcs(:)
      INTEGER, INTENT(in) :: nct
      INTEGER, INTENT(out) :: ncp(:), ncpw(:), ncps(:)
      INTEGER, INTENT(out) :: ngp(:), ngpw(:), ngps(:)
      INTEGER, INTENT(in) :: nproc ! number of proc in the g-vec group

      INTEGER :: mc, i1, i2, i, jj

      IF ( .not. tk ) THEN

        !  when gamma symmetry is used only the sticks of half reciprocal space
        !  are generated, then here we pair-up the sticks with those of the other
        !  half of the space, using the gamma symmetry relation
        !  Note that the total numero of stick "nct" is not modified

        DO mc = 1, nct
           i = idx(mc)
           i1 = in1(i)
           i2 = in2(i)
           IF( i1 == 0 .and. i2 == 0 ) THEN
             jj = stown( i1, i2 )
             IF( jj > 0 ) ngp( jj ) = ngp( jj ) + ngc( i ) - 1
             jj = stowns( i1, i2 )
             IF( jj > 0 ) ngps( jj ) = ngps( jj ) + ngcs( i ) - 1
             jj = stownw( i1, i2 )
             IF( jj > 0 ) ngpw( jj ) = ngpw( jj ) + ngcw( i ) - 1
           ELSE
             jj = stown( i1, i2 )
             IF( jj > 0 ) THEN
               stown( -i1, -i2 ) = jj
               ncp( jj ) = ncp( jj ) + 1
               ngp( jj ) = ngp( jj ) + ngc( i )
             ENDIF
             jj = stowns( i1, i2 )
             IF( jj > 0 ) THEN
               stowns( -i1, -i2 ) = jj
               ncps( jj ) = ncps( jj ) + 1
               ngps( jj ) = ngps( jj ) + ngcs( i )
             ENDIF
             jj = stownw( i1, i2 )
             IF( jj > 0 ) THEN
               stownw( -i1, -i2 ) = jj
               ncpw( jj ) = ncpw( jj ) + 1
               ngpw( jj ) = ngpw( jj ) + ngcw( i )
             ENDIF
           ENDIF
        ENDDO

      ENDIF

      IF( allocated( sticks_owner ) ) DEALLOCATE( sticks_owner )
      ALLOCATE( sticks_owner( lb(1): ub(1), lb(2):ub(2) ) )

      sticks_owner( :, : ) = abs( stown( :, :) )

      RETURN
    END SUBROUTINE sticks_pairup


    SUBROUTINE sticks_set_owner( ub, lb, stown )
      INTEGER, INTENT(in) :: ub(:), lb(:)
      INTEGER, INTENT(inout) :: stown( lb(1): ub(1), lb(2):ub(2) ) ! stick map for potential
      IF( allocated( sticks_owner ) ) DEALLOCATE( sticks_owner )
      ALLOCATE( sticks_owner( lb(1): ub(1), lb(2):ub(2) ) )
      sticks_owner( :, : ) = abs( stown( :, :) )
      RETURN
    END SUBROUTINE sticks_set_owner


!=----------------------------------------------------------------------=

    SUBROUTINE sticks_ordered_dist( tk, ub, lb, idx, in1, in2, ngc, ngcw, ngcs, nct, &
                            ncp, ncpw, ncps, ngp, ngpw, ngps, stown, stownw, stowns, nproc )
!
! This routine works as sticks_dist only it distributes the sticks according to sticks_owner.
! This ensures that the gvectors for any 'smooth like grid' remain on the same proc as the
! original grid.
!
      LOGICAL, INTENT(in) :: tk

      INTEGER, INTENT(in) :: ub(:), lb(:), idx(:)
      INTEGER, INTENT(out) :: stown( lb(1): ub(1), lb(2):ub(2) ) ! stick map for potential
      INTEGER, INTENT(out) :: stownw(lb(1): ub(1), lb(2):ub(2) ) ! stick map for wave functions
      INTEGER, INTENT(out) :: stowns(lb(1): ub(1), lb(2):ub(2) ) ! stick map for smooth mesh

      INTEGER, INTENT(in) :: in1(:), in2(:)
      INTEGER, INTENT(in) :: ngc(:), ngcw(:), ngcs(:)
      INTEGER, INTENT(in) :: nct
      INTEGER, INTENT(out) :: ncp(:), ncpw(:), ncps(:)
      INTEGER, INTENT(out) :: ngp(:), ngpw(:), ngps(:)
      INTEGER, INTENT(in) :: nproc ! number of proc in the g-vec group

      INTEGER :: mc, i1, i2, i, j, jj

      ncp  = 0
      ncps = 0
      ncpw = 0
      ngp  = 0
      ngps = 0
      ngpw = 0

      stown  = sticks_owner
      stownw = 0
      stowns = 0

      DO mc = 1, nct

         i = idx( mc )
!
! index has no effect in this case
!
         i1 = in1( i )
         i2 = in2( i )
!
         IF ( ( .not. tk ) .and. ( (i1 < 0) .or. ( (i1 == 0) .and. (i2 < 0) ) ) ) GOTO 30
!
         ! potential mesh set according to sticks_owner

         jj = stown(i1,i2)
         ncp(jj) = ncp(jj) + 1
         ngp(jj) = ngp(jj) + ngc(i)

         ! smooth mesh

         IF ( ngcs(i) > 0 ) THEN
            ncps(jj) = ncps(jj) + 1
            ngps(jj) = ngps(jj) + ngcs(i)
            stowns(i1,i2) = jj
         ENDIF

         ! wave functions mesh

         IF ( ngcw(i) > 0 ) THEN
            ncpw(jj) = ncpw(jj) + 1
            ngpw(jj) = ngpw(jj) + ngcw(i)
            stownw(i1,i2) = jj
         ENDIF

 30      CONTINUE

      ENDDO

      RETURN
    END SUBROUTINE sticks_ordered_dist

!=----------------------------------------------------------------------=
    
!---------------------------------------------------------------------
    SUBROUTINE hpsort (n, ra, ind)
      !---------------------------------------------------------------------
      ! sort an array ra(1:n) into ascending order using heapsort algorithm.
      ! n is input, ra is replaced on output by its sorted rearrangement.
      ! create an index table (ind) by making an exchange in the index array
      ! whenever an exchange is made on the sorted data array (ra).
      ! in case of equal values in the data array (ra) the values in the
      ! index array (ind) are used to order the entries.
      ! if on input ind(1)  = 0 then indices are initialized in the routine,
      ! if on input ind(1) != 0 then indices are assumed to have been
      !                initialized before entering the routine and these
      !                indices are carried around during the sorting process
      !
      ! no work space needed !
      ! free us from machine-dependent sorting-routines !
      !
      ! adapted from Numerical Recipes pg. 329 (new edition)
      !
      IMPLICIT NONE
      !-input/output variables
      INTEGER :: n
      INTEGER :: ind (n)
      REAL(DP) :: ra (n)
      !-local variables
      INTEGER :: i, ir, j, l, iind
      REAL(DP) :: rra
      ! initialize index array
      IF (ind (1) ==0) THEN
         DO i = 1, n
            ind (i) = i
         ENDDO
      ENDIF
      ! nothing to order
      IF (n<2) RETURN
      ! initialize indices for hiring and retirement-promotion phase
      l = n / 2 + 1
      ir = n
10    CONTINUE
      ! still in hiring phase
      IF (l>1) THEN
         l = l - 1
         rra = ra (l)
         iind = ind (l)
         ! in retirement-promotion phase.
      ELSE
         ! clear a space at the end of the array
         rra = ra (ir)
         !
         iind = ind (ir)
         ! retire the top of the heap into it
         ra (ir) = ra (1)
         !
         ind (ir) = ind (1)
         ! decrease the size of the corporation
         ir = ir - 1
         ! done with the last promotion
         IF (ir==1) THEN
            ! the least competent worker at all !
            ra (1) = rra
            !
            ind (1) = iind
            RETURN
         ENDIF
      ENDIF
      ! wheter in hiring or promotion phase, we
      i = l
      ! set up to place rra in its proper level
      j = l + l
      !
      DO WHILE (j<=ir)
         IF (j<ir) THEN
            ! compare to better underling
            IF (ra (j) <ra (j + 1) ) THEN
               j = j + 1
            ELSEIF (ra (j) ==ra (j + 1) ) THEN
               IF (ind (j) <ind (j + 1) ) j = j + 1
            ENDIF
         ENDIF
         ! demote rra
         IF (rra<ra (j) ) THEN
            ra (i) = ra (j)
            ind (i) = ind (j)
            i = j
            j = j + j
         ELSEIF (rra==ra (j) ) THEN
            ! demote rra
            IF (iind<ind (j) ) THEN
               ra (i) = ra (j)
               ind (i) = ind (j)
               i = j
               j = j + j
            ELSE
               ! set j to terminate do-while loop
               j = ir + 1
            ENDIF
            ! this is the right place for rra
         ELSE
            ! set j to terminate do-while loop
            j = ir + 1
         ENDIF
      ENDDO
      ra (i) = rra
      ind (i) = iind
      GOTO 10
      !
    END SUBROUTINE hpsort

    SUBROUTINE sticks_deallocate
      IF( allocated( sticks_owner ) ) DEALLOCATE( sticks_owner )
      RETURN
    END SUBROUTINE sticks_deallocate

!=----------------------------------------------------------------------=
   END MODULE stick_base
!=----------------------------------------------------------------------=
