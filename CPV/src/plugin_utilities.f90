!-----------------------------------------------------------------------
SUBROUTINE v_h_of_rho_g( rhog, ehart, charge, v )
!-----------------------------------------------------------------------

      !  this routine computes the R-space electrostatic potential of a 
      !  density (possibly with two spin components) provided in G-space
      !  
      !  rho(ig) = (sum over ispin) rho(ig,ispin)
      !  v_h(ig) = fpi / ( g(ig) * tpiba2 ) * rho(ig) 
      !  v_h(ir) = invfft(v_h(ig))
      !  ehart   = Fact * omega * (sum over ig) * fpi / ( gg(ig) * tpiba2 ) *
      !            | rho(ig) |**2
      !  if Gamma symmetry Fact = 1 else Fact = 1/2
      !

      USE kinds,              ONLY: DP
      USE constants,          ONLY: fpi
      USE io_global,          ONLY: stdout
      USE cell_base,          ONLY: tpiba2, tpiba, omega
      USE gvect,              ONLY: gstart, gg
      USE mp_global,          ONLY: intra_bgrp_comm
      USE mp,                 ONLY: mp_sum
      USE fft_base,           ONLY: dfftp
      USE fft_interfaces,     ONLY: fwfft, invfft
      USE electrons_base,     ONLY: nspin
      USE fft_helper_subroutines, ONLY: fftx_oned2threed

      IMPLICIT NONE

      ! ... Arguments

      COMPLEX(DP), INTENT(IN)    :: rhog(dfftp%ngm, nspin)
      REAL(DP),    INTENT(INOUT) :: v(dfftp%nnr, nspin)
      REAL(DP),    INTENT(OUT)   :: ehart, charge

      ! ... Locals

      INTEGER :: ig
      REAL(DP) :: rhog_re, rhog_im, fpibg
      COMPLEX(DP),    ALLOCATABLE   :: aux1(:)
      COMPLEX(DP), ALLOCATABLE   :: aux(:)
      !
      ! ... compute potential in G space ...
      !
      ehart = 0.0d0
      ALLOCATE(aux1(dfftp%ngm))
      ALLOCATE(aux(dfftp%nnr))
      aux1(1) = 0.D0
      DO ig = gstart, dfftp%ngm 
        rhog_re  = REAL(rhog( ig, 1 ))
        rhog_im  = AIMAG(rhog( ig, 1 ))
        IF ( nspin .EQ. 2 ) THEN 
          rhog_re = rhog_re + REAL(rhog( ig, 2 ))
          rhog_im = rhog_im + AIMAG(rhog( ig, 2 ))
        ENDIF
        fpibg = fpi / ( gg(ig) * tpiba2 )
        aux1(ig) = CMPLX( fpibg * rhog_re , fpibg * rhog_im, kind=DP )
        ehart = ehart + fpibg * ( rhog_re**2 + rhog_im**2 )
      END DO
      !
      ! ... energy
      !
      ehart = ehart * omega
      CALL mp_sum(ehart, intra_bgrp_comm)
      !
      ! ... transform hartree potential to real space
      !
      CALL fftx_oned2threed( dfftp, aux, aux1 )
      CALL invfft ('Rho', aux, dfftp)
      !
      ! ... add hartree potential to the input potential
      !
      v(:,1) = v(:,1) + DBLE (aux(:))
      IF ( nspin .EQ. 2 ) v(:,2) = v(:,2) + DBLE (aux(:))
      !
      ! ... G = 0 element
      !
      charge = 0.D0
      IF ( gstart == 2 ) THEN
        charge = omega*REAL(rhog(1,1))
        IF ( nspin == 2 ) charge = charge + omega*REAL(rhog(1,2))
      END IF
      CALL mp_sum(charge, intra_bgrp_comm)
      !
      DEALLOCATE(aux1)
      DEALLOCATE(aux)
      !
      RETURN
!-----------------------------------------------------------------------
  END SUBROUTINE v_h_of_rho_g
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
  SUBROUTINE v_h_of_rho_r( rhor, ehart, charge, v )
!-----------------------------------------------------------------------

      !  this routine computes the R-space electrostatic potential of a 
      !  density (possibly with two spin components) provided in R-space
      !  
      !  rhor(ir) = (sum over ispin) rhor(ir,ispin)
      !  rhog(ig) = fwfft(rhog(ir))
      !  charge   = rhog(0)
      !  v_h(ig)  = fpi / ( g(ig) * tpiba2 ) * rho_e(ig) 
      !  v_h(ir)  = invfft(v_h(ig))
      !  ehart    = Fact * omega * (sum over ig) * fpi / ( gg(ig) * tpiba2 ) *
      !             | rhog(ig) |**2
      !  if Gamma symmetry Fact = 1 else Fact = 1/2
      !
      USE kinds,              ONLY: DP
      USE fft_base,           ONLY: dfftp
      USE fft_interfaces,     ONLY: fwfft, invfft
      USE electrons_base,     ONLY: nspin
      USE fft_helper_subroutines, ONLY: fftx_threed2oned

      IMPLICIT NONE

      ! ... Arguments

      REAL(DP), INTENT(IN)    :: rhor(dfftp%nnr, nspin)
      REAL(DP), INTENT(INOUT) :: v(dfftp%nnr, nspin)
      REAL(DP), INTENT(OUT)   :: ehart, charge

      ! ... Locals
      
      INTEGER :: is
      COMPLEX(DP), ALLOCATABLE   :: aux(:)
      COMPLEX(DP), ALLOCATABLE   :: rhog(:,:)
      !
      ! ... bring the (unsymmetrized) rho(r) to G-space (use aux as work array)
      !
      ALLOCATE( rhog( dfftp%ngm, nspin ) )
      ALLOCATE( aux( dfftp%nnr ) )
      DO is = 1, nspin
        aux(:) = CMPLX(rhor( : , is ),0.D0,kind=dp) 
        CALL fwfft ('Rho', aux, dfftp)
        CALL fftx_threed2oned( dfftp, aux, rhog(:,is) )
      END DO
      !
      ! ... compute VH(r) from rho(G) 
      !
      CALL v_h_of_rho_g( rhog, ehart, charge, v )
      DEALLOCATE( aux )
      DEALLOCATE( rhog )
      !
      RETURN
!-----------------------------------------------------------------------
  END SUBROUTINE v_h_of_rho_r
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
  SUBROUTINE force_h_of_rho_g( rhog, ei1, ei2, ei3, omega, fion )
!-----------------------------------------------------------------------

      !  this routine computes:
      !
      !  Local contribution to the forces on the ions
      !  eigrx(ig,isa)   = ei1( mill(1,ig), isa)
      !  eigry(ig,isa)   = ei2( mill(2,ig), isa)
      !  eigrz(ig,isa)   = ei3( mill(3,ig), isa)
      !  fpibg           = fpi / ( g(ig) * tpiba2 )
      !  tx_h(ig,is)     = fpibg * rhops(ig, is) * CONJG( rho(ig) )
      !  gx(ig)          = cmplx(0.D0, gx(1,ig),kind=DP) * tpiba
      !  fion(x,isa)     = fion(x,isa) + 
      !      Fact * omega * ( sum over ig, iss) tx_h(ig,is) * gx(ig) * 
      !      eigrx(ig,isa) * eigry(ig,isa) * eigrz(ig,isa) 
      !  if Gamma symmetry Fact = 2.0 else Fact = 1
      !

      USE kinds,              ONLY: DP
      USE constants,          ONLY: fpi
      USE cell_base,          ONLY: tpiba2, tpiba
      USE io_global,          ONLY: stdout
      USE gvect,              ONLY: mill, gstart, g, gg
      USE ions_base,          ONLY: nat, nsp, na, rcmax, zv
      USE fft_base,           ONLY: dfftp, dffts
      USE mp_global,          ONLY: intra_bgrp_comm
      USE mp,                 ONLY: mp_sum

      IMPLICIT NONE

      ! ... Arguments

      COMPLEX(DP), INTENT(IN) :: rhog(dfftp%ngm)
      COMPLEX(DP), INTENT(IN) :: ei1(-dfftp%nr1:dfftp%nr1,nat)
      COMPLEX(DP), INTENT(IN) :: ei2(-dfftp%nr2:dfftp%nr2,nat)
      COMPLEX(DP), INTENT(IN) :: ei3(-dfftp%nr3:dfftp%nr3,nat)
      REAL(DP), INTENT(IN)    :: omega
      REAL(DP), INTENT(INOUT) :: fion(3,nat)

      ! ... Locals

      INTEGER     :: is, ia, isa, ig, ig1, ig2, ig3
      REAL(DP)    :: fpibg, rhops, r2new
      COMPLEX(DP) :: rho, gxc, gyc, gzc
      COMPLEX(DP) :: teigr, cnvg, tx, ty, tz
      COMPLEX(DP), ALLOCATABLE :: ftmp(:,:)

      ! ... Subroutine body ...

      ALLOCATE( ftmp( 3, nat ) )
      
      ftmp = 0.0d0

      DO ig = gstart, dffts%ngm

        RHO   = RHOG( ig )
        FPIBG = fpi / ( gg(ig) * tpiba2 )

        ig1  = mill(1,IG)
        ig2  = mill(2,IG)
        ig3  = mill(3,IG)
        GXC  = CMPLX(0.D0,g(1,IG),kind=DP)
        GYC  = CMPLX(0.D0,g(2,IG),kind=DP)
        GZC  = CMPLX(0.D0,g(3,IG),kind=DP)
        isa = 1
        DO IS = 1, nsp
           r2new = 0.25d0 * tpiba2 * rcmax(is)**2
           RHOPS = - zv(is) * exp( -r2new * gg(ig) ) / omega
           CNVG  = RHOPS * FPIBG * CONJG(rho)
           TX = CNVG * GXC
           TY = CNVG * GYC
           TZ = CNVG * GZC
           DO IA = 1, na(is)
              TEIGR = ei1(IG1,ISA) * ei2(IG2,ISA) * ei3(IG3,ISA)
              ftmp(1,ISA) = ftmp(1,ISA) + TEIGR*TX
              ftmp(2,ISA) = ftmp(2,ISA) + TEIGR*TY
              ftmp(3,ISA) = ftmp(3,ISA) + TEIGR*TZ
              isa = isa + 1
           END DO
        END DO

      END DO
      !
      CALL mp_sum( ftmp, intra_bgrp_comm )
      !
      fion = fion + DBLE(ftmp) * 2.D0 * omega * tpiba

      DEALLOCATE( ftmp )
       
      RETURN
!-----------------------------------------------------------------------
  END SUBROUTINE force_h_of_rho_g
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
SUBROUTINE gradv_h_of_rho_r( rho, gradv )
!-----------------------------------------------------------------------

      !  this routine computes the R-space gradient of the electrostatic 
      !  potential of a spinless density in R-space
      !  
      !  rho(ig) = fwfft(rho(ir))
      !  gradv_h(ig,ipol) = fpi * g(ig,ipol) / ( gg(ig) * tpiba ) * rho(ig) 
      !  gradv_h(ir,ipol) = invfft(gradv_h(ig,ipol))
      !

      USE kinds,              ONLY: DP
      USE constants,          ONLY: fpi
      USE io_global,          ONLY: stdout
      USE cell_base,          ONLY: tpiba, omega
      USE gvect,              ONLY: gstart, gg, g
      USE mp_global,          ONLY: intra_bgrp_comm
      USE mp,                 ONLY: mp_sum
      USE fft_base,           ONLY: dfftp
      USE fft_interfaces,     ONLY: fwfft, invfft
      USE fft_helper_subroutines, ONLY: fftx_oned2threed, fftx_threed2oned

      IMPLICIT NONE

      ! ... Arguments

      REAL(DP), INTENT(IN)  :: rho(dfftp%nnr)
      REAL(DP), INTENT(OUT) :: gradv(3,dfftp%nnr)

      ! ... Locals
      
      INTEGER :: ipol, ig
      COMPLEX(DP), ALLOCATABLE   :: rhoaux(:)
      COMPLEX(DP), ALLOCATABLE   :: gaux(:)
      COMPLEX(DP), ALLOCATABLE   :: rhog(:)
      !
      ! ... Bring rho to G space
      !
      ALLOCATE( rhoaux( dfftp%nnr ) )
      ALLOCATE( gaux(dfftp%ngm) )
      ALLOCATE( rhog(dfftp%ngm) )
      !
      rhoaux( : ) = CMPLX( rho( : ), 0.D0, KIND=dp ) 
      !
      CALL fwfft('Rho', rhoaux, dfftp)
      CALL fftx_threed2oned( dfftp, rhoaux, rhog )
      !
      !
      ! ... compute gradient of potential in G space ...
      !
      DO ipol = 1, 3
         !
         gaux(1) = (0.d0,0.d0)
         !
         DO ig = gstart, dfftp%ngm 
           gaux(ig) = CMPLX(0.0d0,1.0d0,kind=DP) * fpi * g(ipol,ig) / ( gg(ig) * tpiba ) * rhog( ig )
         ENDDO
         !
         ! ... bring back to R-space, (\grad_ipol a)(r) ...
         !
         CALL fftx_oned2threed( dfftp, rhoaux, gaux )
         CALL invfft ('Rho', rhoaux, dfftp)
         !
         gradv(ipol,:) = REAL( rhoaux(:) )
         !
      END DO
      !
      DEALLOCATE(rhog)
      DEALLOCATE(gaux)
      DEALLOCATE(rhoaux)
      !
      RETURN
      !
!-----------------------------------------------------------------------
  END SUBROUTINE gradv_h_of_rho_r
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
  SUBROUTINE external_gradient( a, grada )
!-----------------------------------------------------------------------
      ! 
      ! Interface for computing gradients in real space, to be called by
      ! an external module
      !
      USE kinds,            ONLY : DP
      USE fft_base,         ONLY : dfftp
      USE gvect,            ONLY : g
      USE fft_interfaces,   ONLY : fwfft, invfft
      USE fft_helper_subroutines, ONLY: fftx_threed2oned
      !
      IMPLICIT NONE
      !
      REAL( DP ), INTENT(IN)   :: a( dfftp%nnr )
      REAL( DP ), INTENT(OUT)  :: grada( 3, dfftp%nnr )
      !
      ! ... Locals
      !
      INTEGER :: is
      COMPLEX(DP), ALLOCATABLE   :: auxr(:)
      COMPLEX(DP), ALLOCATABLE   :: auxg(:)
      REAL(DP), ALLOCATABLE :: d2rho(:,:)
      REAL(DP), ALLOCATABLE :: dxdyrho(:), dxdzrho(:), dydzrho(:)
      !
      ALLOCATE( auxg( dfftp%ngm ) )
      ALLOCATE( auxr( dfftp%nnr ) )
      ALLOCATE( d2rho(3,dfftp%nnr) )
      ALLOCATE( dxdyrho(dfftp%nnr) )
      ALLOCATE( dxdzrho(dfftp%nnr) ) 
      ALLOCATE( dydzrho(dfftp%nnr) )

      auxr(:) = CMPLX(a( : ),0.D0,kind=dp) 
      CALL fwfft ('Rho', auxr, dfftp)
      CALL fftx_threed2oned( dfftp, auxr, auxg )
      ! from G-space A compute R-space grad(A) 
      CALL gradrho(1,auxg,grada,d2rho,dxdyrho,dxdzrho,dydzrho)

      DEALLOCATE( d2rho, dxdyrho, dxdzrho, dydzrho )
      DEALLOCATE( auxr )
      DEALLOCATE( auxg )
      !
      RETURN
      !
!-----------------------------------------------------------------------
  END SUBROUTINE external_gradient
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
  SUBROUTINE external_hessian( a, grada, hessa )
!-----------------------------------------------------------------------
      ! 
      ! Interface for computing hessians in real space, to be called by
      ! an external module
      !
      USE kinds,            ONLY : DP
      USE fft_base,         ONLY : dfftp
      USE gvect,            ONLY : g
      USE fft_interfaces,   ONLY : fwfft, invfft
      USE fft_helper_subroutines, ONLY: fftx_threed2oned
      !
      IMPLICIT NONE
      !
      REAL( DP ), INTENT(IN)  :: a( dfftp%nnr )
      REAL( DP ), INTENT(OUT) :: grada( 3, dfftp%nnr )
      REAL( DP ), INTENT(OUT) :: hessa( 3, 3, dfftp%nnr )
      !
      ! ... Locals
      !
      INTEGER :: is
      COMPLEX(DP), ALLOCATABLE :: auxr(:)
      COMPLEX(DP), ALLOCATABLE :: auxg(:)
      REAL(DP), ALLOCATABLE :: d2rho(:,:)
      REAL(DP), ALLOCATABLE :: dxdyrho(:), dxdzrho(:), dydzrho(:)
      !
      ALLOCATE( auxg( dfftp%ngm ) )
      ALLOCATE( auxr( dfftp%nnr ) )
      ALLOCATE( d2rho(3,dfftp%nnr) )
      ALLOCATE( dxdyrho(dfftp%nnr) )
      ALLOCATE( dxdzrho(dfftp%nnr) ) 
      ALLOCATE( dydzrho(dfftp%nnr) )

      auxr(:) = CMPLX(a( : ),0.D0,kind=dp) 
      CALL fwfft ('Rho', auxr, dfftp)
      CALL fftx_threed2oned( dfftp, auxr, auxg )
      !
      ! from G-space A compute R-space grad(A) and second derivatives
      CALL gradrho(1,auxg,grada,d2rho,dxdyrho,dxdzrho,dydzrho)
      ! reorder second derivatives
      hessa(1,1,:) = d2rho(1,:)
      hessa(2,2,:) = d2rho(2,:)
      hessa(3,3,:) = d2rho(3,:)
      hessa(1,2,:) = dxdyrho(:)
      hessa(2,1,:) = dxdyrho(:)
      hessa(1,3,:) = dxdzrho(:)
      hessa(3,1,:) = dxdzrho(:)
      hessa(2,3,:) = dydzrho(:)
      hessa(3,2,:) = dydzrho(:)

      DEALLOCATE( d2rho, dxdyrho, dxdzrho, dydzrho )
      DEALLOCATE( auxr )
      DEALLOCATE( auxg )

  RETURN

!-----------------------------------------------------------------------
  END SUBROUTINE external_hessian
!-----------------------------------------------------------------------
