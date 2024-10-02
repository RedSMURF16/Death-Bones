#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define VERSION "1.1"
#define MODEL_SKELETON "models/skeleton.mdl"
#define MAX_PLYAERS 32

#define isPlayer(%1) ( 1 <= %1 <= g_iMaxPlayers )

// Death Bones
#define DEATHBONES_FREQ 0.1
#define DEATHBONES_DETAIL 16

// Drop Bones
#define DROPBONES_DAMAGE_MULTIPLIER 30.0
#define DROPBONES_BLOOD_MULTIPLIER 7.5

// KnockBack Options
#define DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT 400.0
#define DROPBONES_EXPLOSION_KNOCKBACK_CLOSE 500.0
#define DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM 375.0
#define DROPBONES_EXPLOSION_KNOCKBACK_FAR 300.0
#define DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR 250.0

// Explosion Radius
#define DROPBONES_EXPLOSION_RADIUS 200.0
#define DROPBONES_EXPLOSION_RADIUS_CLOSE 125.0
#define DROPBONES_EXPLOSION_RADIUS_MEDIUM 175.0
#define DROPBONES_EXPLOSION_RADIUS_FAR 200.0

// Damage Options
#define DROPBONES_EXPLOSION_DAMAGE_DEFAULT 25.0
#define DROPBONES_EXPLOSION_DAMAGE_CLOSE 40.0
#define DROPBONES_EXPLOSION_DAMAGE_MEDIUM 25.0
#define DROPBONES_EXPLOSION_DAMAGE_FAR 15.0
#define DROPBONES_EXPLOSION_DAMAGE_VERYFAR 10.0

enum _:TaksIds ( += 152439 ){

    TASKID_BONES_IN,
    TASKID_BONES_OUT,
    TASKID_DROPBONES_OUT

}

enum _:Cvars {

    CVAR_DEATHBONES_TIME,
    CVAR_DROPBONES_TIME,
    CVAR_DROPBONES_HEALTH,
    CVAR_DROPBONES_VELOCITY,
    CVAR_DROPBONES_GROUNDBRAKE,

    CVAR_DROPBONES_BLOODSTREAM,

    CVAR_DROPBONES_EXPLOSION,
    CVAR_DROPBONES_EXPLOSION_DAMAGE_IMMUNITY,
    CVAR_DROPBONES_EXPLOSION_KNOCKBACK_IMMUNITY,
    CVAR_DROPBONES_EXPLOSION_EFFECT,
    CVAR_DROPBONES_EXPLOSION_KNOCKBACK,
    CVAR_DROPBONES_EXPLOSION_DAMAGE,
    CVAR_DROPBONES_EXPLOSION_DAMAGETYPE,
    CVAR_DROPBONES_EXPLOSION_RANDOM_DAMAGETYPE,

}

new g_iCvars[ Cvars ]
new const g_szDeathBonesClassName[] = "DeathBones"
new const g_szDropBonesClassName[] = "DropBones"
new g_iSkeleton[ MAX_PLAYERS + 1 ]

new g_iDamageTypes[] = { DMG_GENERIC, DMG_CRUSH, DMG_BULLET, DMG_SLASH, DMG_BURN, DMG_FREEZE, DMG_FALL, DMG_BLAST,
DMG_CLUB, DMG_SHOCK, DMG_SONIC, DMG_ENERGYBEAM, DMG_NEVERGIB, DMG_ALWAYSGIB, DMG_DROWN, DMG_PARALYZE, DMG_NERVEGAS,
DMG_POISON, DMG_RADIATION, DMG_DROWNRECOVER, DMG_ACID, DMG_SLOWBURN, DMG_SLOWFREEZE, DMG_MORTAR, DMG_GRENADE }
new g_iMaxPlayers

public plugin_init(){

    register_plugin( "Death Bones", VERSION, "RedSMURF" )

    g_iCvars[ CVAR_DEATHBONES_TIME ] = register_cvar( "deathbones_time", "50" ) // 
    g_iCvars[ CVAR_DROPBONES_TIME ] = register_cvar( "dropbones_time", "10" ) // 
    g_iCvars[ CVAR_DROPBONES_HEALTH ] = register_cvar( "dropbones_health", "1" ) // 
    g_iCvars[ CVAR_DROPBONES_VELOCITY ] = register_cvar( "dropbones_velocity", "450" ) // 
    g_iCvars[ CVAR_DROPBONES_GROUNDBRAKE ] = register_cvar( "dropbones_groundbrake", "0.5" ) // 

    g_iCvars[ CVAR_DROPBONES_BLOODSTREAM ] = register_cvar( "dropbones_bloodstream", "1" ) // 0 1

    g_iCvars[ CVAR_DROPBONES_EXPLOSION ] = register_cvar( "dropbones_explosion", "1" ) // 0 1
    g_iCvars[ CVAR_DROPBONES_EXPLOSION_KNOCKBACK ] = register_cvar( "dropbones_explosion_knockback", "2" ) // 0 - off || 1 - aio || 2 - region
    g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGE ] = register_cvar( "dropbones_explosion_damage", "2" ) // 0 - off || 1 - aio || 2 - region || 3 - random
    g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGETYPE ] = register_cvar( "dropbones_explosion_damagetype", "8" ) 
    g_iCvars[ CVAR_DROPBONES_EXPLOSION_RANDOM_DAMAGETYPE ] = register_cvar( "dropbones_explosion_random_damagetype", "1" ) // 0 1
    g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGE_IMMUNITY ] = register_cvar( "dropbones_explosion_damage_immunity", "0" ) // 0 1
    g_iCvars[ CVAR_DROPBONES_EXPLOSION_KNOCKBACK_IMMUNITY ] = register_cvar( "dropbones_explosion_knockback_immunity", "0" ) // 0 1

    register_forward( FM_TraceLine, "fwTraceLine" )
    // register_logevent( "EvRoundEnd", 2, "1=Round_End" ) // removes all bones

    register_clcmd( "drop", "DropBones", ADMIN_LEVEL_A )

    g_iMaxPlayers = get_maxplayers()

}

public plugin_precache(){

    precache_model( MODEL_SKELETON )

    RegisterHam( Ham_Spawn, "player", "HamPlayerSpawn", 0 ) // re-setting player rendering || remove bones
    RegisterHam( Ham_Killed, "player", "HamPlayerKilled", 0 ) // show bones && player fades

    RegisterHam( Ham_Touch, "info_target", "HamDropBonesTouch", 0 ) // brakes on ground
    RegisterHam( Ham_TakeDamage, "info_target", "HamDropBonesDamage", 0 ) // covers both shooting/radius damamges
    // RegisterHam( Ham_TraceAttack, "info_target", "HamDropBonesShoot", 0 )
    RegisterHam( Ham_Killed, "info_target", "HamDropBonesKilled", 0 ) // render effects

}

public client_disconnected( id ){

    if ( pev_valid( g_iSkeleton[ id ] )){

        if ( !task_exists( TASKID_BONES_OUT + id ) ){

            if ( task_exists( TASKID_BONES_IN + id ) )
                remove_task( TASKID_BONES_IN + id )

            BonesOut( TASKID_BONES_OUT + id )

        }else {

            remove_task( TASKID_BONES_OUT + id )
            BonesOut( TASKID_BONES_OUT + id )

        }

    }

}

public HamPlayerSpawn( id ){

    if ( pev_valid( g_iSkeleton[ id ] ) ){

        if ( !task_exists( TASKID_BONES_OUT + id ) ){

            if ( task_exists( TASKID_BONES_IN + id ) )
                remove_task( TASKID_BONES_IN + id ) 

            BonesOut( TASKID_BONES_OUT + id )

        }else {

            remove_task( TASKID_BONES_OUT + id ) 
            BonesOut( TASKID_BONES_OUT + id )

        }
    }

    set_pev( id, pev_rendermode, kRenderNormal )
    set_pev( id, pev_renderamt, 0.0 )

    return HAM_IGNORED

}

// public EvRoundEnd(){

//     // client_print( 1, print_chat, "ROUND DRAW" )

//     for ( new id = 1; id <= g_iMaxPlayers; id ++ ){

//         if ( pev_valid( g_iSkeleton[ id ] )){

//             if ( !task_exists( TASKID_BONESOUT + id ) ){

//                 if ( task_exists( TASKID_BONESIN + id ) )
//                     remove_task( TASKID_BONESIN + id )

//                 BonesOut( TASKID_BONESOUT + id )

//             }else {

//                 remove_task( TASKID_BONESOUT + id )
//                 BonesOut( TASKID_BONESOUT + id )

//             }

//         }

//     }

// }

// Create Bones with default properties
public createBones(){

    new iBones = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, "info_target" ) )
    if ( !pev_valid( iBones ) ) return PLUGIN_HANDLED

    engfunc( EngFunc_SetModel, iBones, MODEL_SKELETON ) // CRUCIAL

    set_pev( iBones, pev_solid, SOLID_NOT )
    set_pev( iBones, pev_movetype, MOVETYPE_NONE )

    set_pev( iBones, pev_renderfx, kRenderFxNone )
    set_pev( iBones, pev_rendercolor, 0, 0, 0 )
    set_pev( iBones, pev_rendermode, kRenderNormal )
    set_pev( iBones, pev_renderamt, 0.0 )

    return iBones

}

public DropBones( id ){

    new iWpn = get_user_weapon( id, _, _ )

    if ( iWpn != CSW_KNIFE )
        return PLUGIN_CONTINUE

    new Float:fOrigin[ 3 ], Float:fVelocity[ 3 ], Float:fAVelocity[ 3 ]
    pev( id, pev_origin, fOrigin )
    velocity_by_aim( id, get_pcvar_num( g_iCvars[ CVAR_DROPBONES_VELOCITY ] ), fVelocity )

    fVelocity[ 2 ] += 50.0
    fAVelocity[ 1 ] = random_float( -1000.0, 1000.0 )

    new iBones = createBones()
    if ( !pev_valid( iBones ) ) return PLUGIN_CONTINUE

    set_pev( iBones, pev_classname, g_szDropBonesClassName ) // CRUCIAL

    set_pev( iBones, pev_origin, fOrigin )
    set_pev( iBones, pev_velocity, fVelocity )
    set_pev( iBones, pev_avelocity, fAVelocity )

    set_pev( iBones, pev_health, get_pcvar_float( g_iCvars[ CVAR_DROPBONES_HEALTH ] ))
    set_pev( iBones, pev_takedamage, DAMAGE_YES )

    set_pev( iBones, pev_solid, SOLID_TRIGGER )
    set_pev( iBones, pev_movetype, MOVETYPE_BOUNCE )

    set_task( get_pcvar_float( g_iCvars[ CVAR_DROPBONES_TIME ] ), "DropBonesOut", iBones + TASKID_DROPBONES_OUT )

    return PLUGIN_HANDLED

}

public HamDropBonesTouch( iBones, iOther ){

    if ( !isDropBonesEnt( iBones ) ) return HAM_IGNORED

    if ( pev( iOther, pev_solid ) < SOLID_BBOX ) return HAM_IGNORED
    if ( isPlayer( iOther ) ) return HAM_IGNORED

    new Float:fVelocity[ 3 ]
    pev( iBones, pev_velocity, fVelocity )

    xs_vec_mul_scalar( fVelocity, get_pcvar_float( g_iCvars[ CVAR_DROPBONES_GROUNDBRAKE ] ), fVelocity )
    set_pev( iBones, pev_velocity, fVelocity )

    return HAM_IGNORED

}

public HamDropBonesDamage( iBones, iInflictor, iAttacker, Float:fDamage, iDamageBits ){

    if ( !isDropBonesEnt( iBones ) ) return HAM_IGNORED

    new szAttackerClassName[ 32 ]
    pev( iAttacker, pev_classname, szAttackerClassName, sizeof( szAttackerClassName ) )

    if ( equal( szAttackerClassName, g_szDropBonesClassName ) && get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGE_IMMUNITY ] )){

        SetHamParamFloat( 4, 0.0 )
        return HAM_IGNORED

    }

    new Float:fBonesOrigin[ 3 ], Float:fInflictorOrigin[ 3 ], Float:fBonesVelocity[ 3 ], Float:fBonesAVelocity[ 3 ]
    pev( iBones, pev_origin, fBonesOrigin )
    pev( iInflictor, pev_origin, fInflictorOrigin )
    pev( iBones, pev_velocity, fBonesVelocity )

    fBonesAVelocity[ 1 ] = random_float( -1000.0, 1000.0 )

    new Float:fTemp[ 3 ], Float:fHealth
    pev( iBones, pev_health, fHealth )

    xs_vec_sub( fBonesOrigin, fInflictorOrigin, fTemp )
    xs_vec_normalize( fTemp, fTemp )

    xs_vec_mul_scalar( fTemp, DROPBONES_DAMAGE_MULTIPLIER * fDamage, fTemp )
    fTemp[ 2 ] *= 2.5
    xs_vec_add( fTemp, fBonesVelocity, fBonesVelocity )

    if ( fHealth > fDamage && get_pcvar_num( g_iCvars[ CVAR_DROPBONES_BLOODSTREAM ] ))
        BloodStream( fBonesOrigin, fDamage, fTemp )

    set_pev( iBones, pev_velocity, fBonesVelocity )
    set_pev( iBones, pev_avelocity, fBonesAVelocity )

    return HAM_IGNORED

}

// public HamDropBonesShoot( iBones, iAttacker, Float:fDamage, Float:fDirection[ 3 ], iTraceHandler, iDamageBits ){

//     if ( !isDropBonesEnt( iBones ) ) return HAM_IGNORED

//     new Float:fOrigin[ 3 ], Float:fAVelocity[ 3 ], Float:fVelocity[ 3 ]
//     pev( iBones, pev_origin, fOrigin )
//     pev( iBones, pev_velocity, fVelocity )
//     fAVelocity[ 1 ] = random_float( -1000.0, 1000.0 )

//     xs_vec_mul_scalar( fDirection, fDamage, fDirection )
//     xs_vec_mul_scalar( fDirection, g_fDamageMultiplier, fDirection )
//     xs_vec_add( fDirection, fVelocity, fVelocity )

//     BloodStream( fOrigin, fDamage, fDirection )

//     fVelocity[ 2 ] *= 2.0

//     set_pev( iBones, pev_velocity, fVelocity )
//     set_pev( iBones, pev_avelocity, fAVelocity )

//     return HAM_IGNORED

// }

public fwTraceLine( Float:fStart[ 3 ], Float:fEnd[ 3 ], iCondition, id, iTraceLineResult ){

    if ( !isPlayer( id ) ) return FMRES_IGNORED

    new Float:fVecEndPos[ 3 ], iBones = 0, iTraceModelResult = 0
    get_tr2( iTraceLineResult, TR_vecEndPos, fVecEndPos )

    while(( iBones = engfunc( EngFunc_FindEntityInSphere, iBones, fVecEndPos, 35.0 ) )){

        if ( !isDropBonesEnt( iBones ) ) continue 

        engfunc( EngFunc_TraceModel, fStart, fEnd, HULL_HEAD, iBones, iTraceModelResult )

        if ( pev_valid( get_tr2( iTraceModelResult, TR_pHit ) )){

            get_tr2( iTraceModelResult, TR_vecEndPos, fVecEndPos )
            set_tr2( iTraceLineResult, TR_vecEndPos, fVecEndPos )

            set_tr2( iTraceLineResult, TR_pHit, iBones )

            return FMRES_SUPERCEDE

        }

    }

    return FMRES_IGNORED

}

public HamDropBonesKilled( iBones ){

    if ( !isDropBonesEnt( iBones ) ) return HAM_IGNORED
    if ( !pev_valid( iBones ) ) return HAM_IGNORED

    if ( task_exists( iBones + TASKID_DROPBONES_OUT ) )
        remove_task( iBones + TASKID_DROPBONES_OUT )

    KillDropBones( iBones )

    return HAM_IGNORED

}

// gathers all "kill dropbones" procedures in one function to avoid duplication
public KillDropBones( iBones ){

    new Float:fOrigin[ 3 ]
    pev( iBones, pev_origin, fOrigin )

    // set_pev( iBones, pev_flags, FL_KILLME )
    engfunc( EngFunc_RemoveEntity, iBones ) // Remove bones immediately

    if ( get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION ] )){

        BonesExplode( fOrigin )

        if ( get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGE ] ) || get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_KNOCKBACK ] ) )
            BonesEffect( fOrigin ) // Explosion physical effect 

    }

}

// Each case has it's own properties that should be set, for instance when players dies based on our algorithme 
// We should the Bones origin and anlges properties
public HamPlayerKilled( id ){

    new Float:fOrigin[ 3 ], Float:fAngles[ 3 ], iFlags
    pev( id, pev_origin, fOrigin )
    pev( id, pev_angles, fAngles )
    iFlags = pev( id, pev_flags )

    if ( iFlags & IN_DUCK )
        fOrigin[ 2 ] -= 18.0
    else 
        fOrigin[ 2 ] -= 32.0

    if ( !pev_valid( g_iSkeleton[ id ] ) )
        g_iSkeleton[ id ] = createBones()

    set_pev( g_iSkeleton[ id ], pev_classname, g_szDeathBonesClassName ) // CRUCIAL

    set_pev( g_iSkeleton[ id ], pev_origin, fOrigin )
    set_pev( g_iSkeleton[ id ], pev_angles, fAngles )

    set_pev( g_iSkeleton[ id ], pev_solid, SOLID_NOT )
    set_pev( g_iSkeleton[ id ], pev_movetype, MOVETYPE_TOSS )

    set_pev( g_iSkeleton[ id ], pev_rendermode, kRenderTransAlpha )
    set_pev( g_iSkeleton[ id ], pev_renderamt, 0.0 )

    set_task( 1.0, "BonesIn", TASKID_BONES_IN + id )

    return HAM_IGNORED

}

public BonesIn( iTask ){

    new id = iTask - TASKID_BONES_IN
    new iAlpha = pev( g_iSkeleton[ id ], pev_iuser4 ) + 1

    if ( !pev_valid( g_iSkeleton[ id ] ) ) 
        return PLUGIN_HANDLED

    // Remove Player
    set_pev( id, pev_rendermode, kRenderTransAlpha )
    set_pev( id, pev_renderamt, float( 256 - iAlpha * DEATHBONES_DETAIL ))

    // Show Skeleton
    set_pev( g_iSkeleton[ id ], pev_rendermode, kRenderTransAlpha )
    set_pev( g_iSkeleton[ id ], pev_renderamt, float( iAlpha * DEATHBONES_DETAIL - 1 ) )

    set_pev( g_iSkeleton[ id ], pev_iuser4, iAlpha )

    if ( iAlpha * DEATHBONES_DETAIL >= 256 ){

        HidePlayer( id )
        set_task( get_pcvar_float( g_iCvars[ CVAR_DEATHBONES_TIME ] ), "BonesOut", TASKID_BONES_OUT + id ) // Time to remove bones 

    }else 
        set_task( DEATHBONES_FREQ, "BonesIn", TASKID_BONES_IN + id ) // Showing Bones gradually 

    return PLUGIN_HANDLED

}

public HidePlayer( id ){

    new Float:fOrigin[ 3 ]
    pev( id, pev_origin, fOrigin )
    fOrigin[ 2 ] -= 50.0
    set_pev( id, pev_origin, fOrigin )

}

public BonesOut( iTask ){

    new id = iTask - TASKID_BONES_OUT
    new iAlpha = pev( g_iSkeleton[ id ], pev_iuser4 ) - 1

    if ( !pev_valid( g_iSkeleton[ id ] ) ) 
        return PLUGIN_HANDLED

    // Remove Skeleton
    set_pev( g_iSkeleton[ id ], pev_rendermode, kRenderTransAlpha )
    set_pev( g_iSkeleton[ id ], pev_renderamt, float( iAlpha * DEATHBONES_DETAIL ) )

    set_pev( g_iSkeleton[ id ], pev_iuser4, iAlpha )

    if ( iAlpha * DEATHBONES_DETAIL <= 0 ){

        set_pev( g_iSkeleton[ id ], pev_flags, FL_KILLME )
        g_iSkeleton[ id ] = 0

    }else 
        set_task( DEATHBONES_FREQ, "BonesOut", TASKID_BONES_OUT + id )

    return PLUGIN_HANDLED

}

public DropBonesOut( iTask ){

    new iBones = iTask - TASKID_DROPBONES_OUT
    if ( !pev_valid( iBones ) ) return PLUGIN_HANDLED

    KillDropBones( iBones )

    return PLUGIN_HANDLED

}

public BonesExplode( Float:fOrigin[ 3 ] ){

    // message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
    // write_byte( TE_EXPLOSION )
    // write_coord_f( fOrigin[ 0 ] )
    // write_coord_f( fOrigin[ 1 ] )
    // write_coord_f( fOrigin[ 2 ] )
    // write_short( 23 ) // sprite index 0 - 30 flickering particles
    // write_byte( 10 ) // scale 
    // write_byte( 1 ) // framerate
    // write_byte( TE_EXPLFLAG_NODLIGHTS )
    // message_end() 

    message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
    write_byte( TE_TAREXPLOSION )
    write_coord_f( fOrigin[ 0 ] )
    write_coord_f( fOrigin[ 1 ] )
    write_coord_f( fOrigin[ 2 ] )
    message_end() 

    // message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
    // write_byte( TE_EXPLOSION2 )
    // write_coord_f( fOrigin[ 0 ] )
    // write_coord_f( fOrigin[ 1 ] )
    // write_coord_f( fOrigin[ 2 ] )
    // write_byte( 0 )
    // write_byte( 1 )
    // message_end() 

}

public BonesEffect( Float:fBonesOrigin[ 3 ] ){

    new iEnt = 0

    while(( iEnt = engfunc( EngFunc_FindEntityInSphere, iEnt, fBonesOrigin, DROPBONES_EXPLOSION_RADIUS ) )){

        if ( !pev_valid( iEnt ) ) continue
        if ( pev( iEnt, pev_takedamage ) == DAMAGE_NO || pev( iEnt, pev_movetype ) == MOVETYPE_NONE ) continue
        if ( isPlayer( iEnt ) && !is_user_alive( iEnt ) ) continue 

        // Damage related
        new iExplosionDamage = get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGE ] )
        new iExplosionKnockBack = get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_KNOCKBACK ] )
        new iDamageType = get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_RANDOM_DAMAGETYPE ] ) ? 
        g_iDamageTypes[ random_num( 0, sizeof( g_iDamageTypes ) - 1 ) ] : get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_DAMAGETYPE ] )

        // KnockBack related
        new szClassName[ 32 ], Float:fVictimOrigin[ 3 ], Float:fVictimVelocity[ 3 ]
        pev( iEnt, pev_classname, szClassName, sizeof( szClassName ) )
        pev( iEnt, pev_origin, fVictimOrigin )
        pev( iEnt, pev_velocity, fVictimVelocity )

        // Special case for "hostage_entities"
        if ( equal( szClassName, "hostage_entity" ) || equal( szClassName, g_szDropBonesClassName ))
            fVictimOrigin[ 2 ] += 36.0

        new Float:fDirection[ 3 ], Float:fDistance
        xs_vec_sub( fVictimOrigin, fBonesOrigin, fDirection )
        xs_vec_normalize( fDirection, fDirection )
        fDistance = get_distance_f( fBonesOrigin, fVictimOrigin )

        // We first handle the damage option and then move to the knockback 
        switch( iExplosionDamage ){

            case 1 : {

                fakedamage( iEnt, g_szDropBonesClassName, DROPBONES_EXPLOSION_DAMAGE_DEFAULT, iDamageType )

                switch( iExplosionKnockBack ){

                    case 1 : {

                        fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT
                        fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT
                        fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT * 2.0

                    }

                    case 2 : {

                        if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_CLOSE ){
                                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE * 2.0
            
                        }else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_MEDIUM ){
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM * 2.0

                        }else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_FAR ) {
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR * 2.0

                        }else {
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR * 2.0
            
                        }
                    }
                }
            }

            case 2 : {

                if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_CLOSE )
                    fakedamage( iEnt, g_szDropBonesClassName, DROPBONES_EXPLOSION_DAMAGE_CLOSE, iDamageType )
    
                else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_MEDIUM )
                    fakedamage( iEnt, g_szDropBonesClassName, DROPBONES_EXPLOSION_DAMAGE_MEDIUM, iDamageType )
                    
                else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_FAR )
                    fakedamage( iEnt, g_szDropBonesClassName, DROPBONES_EXPLOSION_DAMAGE_FAR, iDamageType )

                else
                    fakedamage( iEnt, g_szDropBonesClassName, DROPBONES_EXPLOSION_DAMAGE_VERYFAR, iDamageType )

                switch( iExplosionKnockBack ){

                    case 1 : {

                        fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT
                        fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT
                        fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT * 2.0

                    }

                    case 2 : {

                        if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_CLOSE ){
                                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE * 2.0
            
                        }else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_MEDIUM ){
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM * 2.0

                        }else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_FAR ) {
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR * 2.0

                        }else {
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR * 2.0
            
                        }
                    }
                }
            }

            default : {

                switch( iExplosionKnockBack ){

                    case 1 : {

                        fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT
                        fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT
                        fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_DEFAULT * 2.0

                    }

                    case 2 : {

                        if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_CLOSE ){
                                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_CLOSE * 2.0
            
                        }else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_MEDIUM ){
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_MEDIUM * 2.0

                        }else if ( fDistance <= DROPBONES_EXPLOSION_RADIUS_FAR ) {
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_FAR * 2.0

                        }else {
                    
                            fDirection[ 0 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR
                            fDirection[ 1 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR
                            fDirection[ 2 ] *= DROPBONES_EXPLOSION_KNOCKBACK_VERYFAR * 2.0
            
                        }
                    }
                }
            }
        }

        xs_vec_add( fDirection, fVictimVelocity, fVictimVelocity )

        // Check bones status before proceeding
        if ( pev_valid( iEnt ) && get_pcvar_num( g_iCvars[ CVAR_DROPBONES_EXPLOSION_KNOCKBACK_IMMUNITY ] ) == 0 )
            set_pev( iEnt, pev_velocity, fVictimVelocity )

    }

}

public BloodStream( Float:fOrigin[ 3 ], Float:fDamage, Float:fDirection[ 3 ] ){

    message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
    write_byte( TE_BLOODSTREAM )
    write_coord_f( fOrigin[ 0 ] )
    write_coord_f( fOrigin[ 1 ] )
    write_coord_f( fOrigin[ 2 ] )
    write_coord_f( fDirection[ 0 ] )
    write_coord_f( fDirection[ 1 ] )
    write_coord_f( DROPBONES_BLOOD_MULTIPLIER * fDamage )
    write_byte( 70 ) // Red 64-78 
    write_byte( 250 )
    message_end()

}

public isDropBonesEnt( iEnt ){

    new szClassName[ 32 ]
    pev( iEnt, pev_classname, szClassName, sizeof( szClassName ) )

    if ( equal( szClassName, g_szDropBonesClassName ) ) 
        return true
    else   
        return false

}

// public GunShot( id, iOrigin[ 3 ] ){

//     message_begin( MSG_BROADCAST, SVC_TEMPENTITY, iOrigin, id )
//     write_byte( TE_GUNSHOT )
//     write_coord( iOrigin[ 0 ] )
//     write_coord( iOrigin[ 1 ] )
//     write_coord( iOrigin[ 2 ] )
//     message_end()

// }

// Handling special events which won't fire the "DeathMsg" Event
// public plugin_log(){
    
//     new Arg1[32], Arg2[32];

//     read_logargv(1, Arg1, sizeof Arg1);
//     read_logargv(2, Arg2, sizeof Arg2);

//     if (equal(Arg1, "committed suicide with") && equal(Arg2, "world")){

//         new Arg0[32], subString[2], i;
//         new numbers[] = "01234566789";
//         new iUser = 0;

//         i = read_logargv(0, Arg0, sizeof Arg0) - 1;
//         subString[0] = Arg0[i];

//         while ( contain(numbers, subString) == -1 ){
//             subString[0] = Arg0[--i];
//         }

//         if ( contain(numbers, Arg0[i - 1]) != -1 ){
//             iUser = str_to_num( Arg0[--i] ) * 10;
//             iUser += str_to_num( Arg0[++i] );
//         } else {
//             iUser = str_to_num( Arg0[i] );
//         }

//         Event_DeathMsg(iUser);

//     }
// }