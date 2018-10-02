--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.13
-- Dumped by pg_dump version 10.4

-- Started on 2018-10-02 21:35:07

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', 'public', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

-- Create postgis extension
CREATE EXTENSION postgis;

--
-- TOC entry 2462 (class 1247 OID 32358)
-- Name: histogram; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.histogram AS (
	min double precision,
	max double precision,
	count bigint,
	percent double precision
);


ALTER TYPE public.histogram OWNER TO postgres;

--
-- TOC entry 2465 (class 1247 OID 32362)
-- Name: quantile; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.quantile AS (
	quantile double precision,
	value double precision
);


ALTER TYPE public.quantile OWNER TO postgres;

--
-- TOC entry 2468 (class 1247 OID 32367)
-- Name: valuecount; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.valuecount AS (
	value double precision,
	count integer,
	percent double precision
);


ALTER TYPE public.valuecount OWNER TO postgres;

--
-- TOC entry 1861 (class 1255 OID 32368)
-- Name: _add_raster_constraint_regular_blocking(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
	BEGIN

		RAISE INFO 'The regular_blocking constraint is just a flag indicating that the column "%" is regularly blocked.  It is up to the end-user to ensure that the column is truely regularly blocked.', quote_ident($3);

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_regular_blocking_' || $3;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (TRUE)';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- TOC entry 1873 (class 1255 OID 32371)
-- Name: _st_aspect4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_aspect4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        pwidth float;
        pheight float;
        dz_dx float;
        dz_dy float;
        aspect float;
    BEGIN
        pwidth := args[1]::float;
        pheight := args[2]::float;
        dz_dx := ((matrix[3][1] + 2.0 * matrix[3][2] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[1][2] + matrix[1][3])) / (8.0 * pwidth);
        dz_dy := ((matrix[1][3] + 2.0 * matrix[2][3] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[2][1] + matrix[3][1])) / (8.0 * pheight);
        IF abs(dz_dx) = 0::float AND abs(dz_dy) = 0::float THEN
            RETURN -1;
        END IF;

        aspect := atan2(dz_dy, -dz_dx);
        IF aspect > (pi() / 2.0) THEN
            RETURN (5.0 * pi() / 2.0) - aspect;
        ELSE
            RETURN (pi() / 2.0) - aspect;
        END IF;
    END;
    $$;


ALTER FUNCTION public._st_aspect4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- TOC entry 1874 (class 1255 OID 32372)
-- Name: _st_hillshade4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_hillshade4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        pwidth float;
        pheight float;
        dz_dx float;
        dz_dy float;
        zenith float;
        azimuth float;
        slope float;
        aspect float;
        max_bright float;
        elevation_scale float;
    BEGIN
        pwidth := args[1]::float;
        pheight := args[2]::float;
        azimuth := (5.0 * pi() / 2.0) - args[3]::float;
        zenith := (pi() / 2.0) - args[4]::float;
        dz_dx := ((matrix[3][1] + 2.0 * matrix[3][2] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[1][2] + matrix[1][3])) / (8.0 * pwidth);
        dz_dy := ((matrix[1][3] + 2.0 * matrix[2][3] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[2][1] + matrix[3][1])) / (8.0 * pheight);
        elevation_scale := args[6]::float;
        slope := atan(sqrt(elevation_scale * pow(dz_dx, 2.0) + pow(dz_dy, 2.0)));
        -- handle special case of 0, 0
        IF abs(dz_dy) = 0::float AND abs(dz_dy) = 0::float THEN
            -- set to pi as that is the expected PostgreSQL answer in Linux
            aspect := pi();
        ELSE
            aspect := atan2(dz_dy, -dz_dx);
        END IF;
        max_bright := args[5]::float;

        IF aspect < 0 THEN
            aspect := aspect + (2.0 * pi());
        END IF;

        RETURN max_bright * ( (cos(zenith)*cos(slope)) + (sin(zenith)*sin(slope)*cos(azimuth - aspect)) );
    END;
    $$;


ALTER FUNCTION public._st_hillshade4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- TOC entry 1882 (class 1255 OID 32373)
-- Name: _st_intersects(public.raster, public.geometry, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_intersects(rast public.raster, geom public.geometry, nband integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE COST 1000
    AS $$
	DECLARE
		gr raster;
		scale double precision;
	BEGIN
		IF ST_Intersects(geom, ST_ConvexHull(rast)) IS NOT TRUE THEN
			RETURN FALSE;
		ELSEIF nband IS NULL THEN
			RETURN TRUE;
		END IF;

		-- scale is set to 1/100th of raster for granularity
		SELECT least(scalex, scaley) / 100. INTO scale FROM ST_Metadata(rast);
		gr := _st_asraster(geom, scale, scale);
		IF gr IS NULL THEN
			RAISE EXCEPTION 'Unable to convert geometry to a raster';
			RETURN FALSE;
		END IF;

		RETURN ST_Intersects(rast, nband, gr, 1);
	END;
	$$;


ALTER FUNCTION public._st_intersects(rast public.raster, geom public.geometry, nband integer) OWNER TO postgres;

--
-- TOC entry 1883 (class 1255 OID 32374)
-- Name: _st_mapalgebra4unionfinal1(public.raster); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_mapalgebra4unionfinal1(rast public.raster) RETURNS public.raster
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
    	-- NOTE: I have to sacrifice RANGE.  Sorry RANGE.  Any 2 banded raster is going to be treated
    	-- as a MEAN
        IF ST_NumBands(rast) = 2 THEN
            RETURN ST_MapAlgebraExpr(rast, 1, rast, 2, 'CASE WHEN [rast2.val] > 0 THEN [rast1.val] / [rast2.val]::float8 ELSE NULL END'::text, NULL::text, 'UNION'::text, NULL::text, NULL::text, NULL::double precision);
        ELSE
            RETURN rast;
        END IF;
    END;
    $$;


ALTER FUNCTION public._st_mapalgebra4unionfinal1(rast public.raster) OWNER TO postgres;

--
-- TOC entry 1884 (class 1255 OID 32375)
-- Name: _st_mapalgebra4unionstate(public.raster, public.raster); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster) RETURNS public.raster
    LANGUAGE sql
    AS $_$
        SELECT _ST_MapAlgebra4UnionState($1,$2, 'LAST', NULL, NULL, NULL, NULL, NULL, NULL, NULL)
    $_$;


ALTER FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster) OWNER TO postgres;

--
-- TOC entry 1885 (class 1255 OID 32376)
-- Name: _st_mapalgebra4unionstate(public.raster, public.raster, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, bandnum integer) RETURNS public.raster
    LANGUAGE sql
    AS $_$
        SELECT _ST_MapAlgebra4UnionState($1,ST_Band($2,$3), 'LAST', NULL, NULL, NULL, NULL, NULL, NULL, NULL)
    $_$;


ALTER FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, bandnum integer) OWNER TO postgres;

--
-- TOC entry 1886 (class 1255 OID 32377)
-- Name: _st_mapalgebra4unionstate(public.raster, public.raster, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, p_expression text) RETURNS public.raster
    LANGUAGE sql
    AS $_$
        SELECT _ST_MapAlgebra4UnionState($1,$2, $3, NULL, NULL, NULL, NULL, NULL, NULL, NULL)
    $_$;


ALTER FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, p_expression text) OWNER TO postgres;

--
-- TOC entry 1887 (class 1255 OID 32378)
-- Name: _st_mapalgebra4unionstate(public.raster, public.raster, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, bandnum integer, p_expression text) RETURNS public.raster
    LANGUAGE sql
    AS $_$
        SELECT _ST_MapAlgebra4UnionState($1, ST_Band($2,$3), $4, NULL, NULL, NULL, NULL, NULL, NULL, NULL)
    $_$;


ALTER FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, bandnum integer, p_expression text) OWNER TO postgres;

--
-- TOC entry 1888 (class 1255 OID 32379)
-- Name: _st_mapalgebra4unionstate(public.raster, public.raster, text, text, text, double precision, text, text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, p_expression text, p_nodata1expr text, p_nodata2expr text, p_nodatanodataval double precision, t_expression text, t_nodata1expr text, t_nodata2expr text, t_nodatanodataval double precision) RETURNS public.raster
    LANGUAGE plpgsql
    AS $$
    DECLARE
        t_raster raster;
        p_raster raster;
    BEGIN
        -- With the new ST_MapAlgebraExpr we must split the main expression in three expressions: expression, nodata1expr, nodata2expr and a nodatanodataval
        -- ST_MapAlgebraExpr(rast1 raster, band1 integer, rast2 raster, band2 integer, expression text, pixeltype text, extentexpr text, nodata1expr text, nodata2expr text, nodatanodatadaval double precision)
        -- We must make sure that when NULL is passed as the first raster to ST_MapAlgebraExpr, ST_MapAlgebraExpr resolve the nodata1expr
        -- Note: rast2 is always a single band raster since it is the accumulated raster thus far
        -- 		There we always set that to band 1 regardless of what band num is requested
        IF upper(p_expression) = 'LAST' THEN
            --RAISE NOTICE 'last asked for ';
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, '[rast2.val]'::text, NULL::text, 'UNION'::text, '[rast2.val]'::text, '[rast1.val]'::text, NULL::double precision);
        ELSIF upper(p_expression) = 'FIRST' THEN
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, '[rast1.val]'::text, NULL::text, 'UNION'::text, '[rast2.val]'::text, '[rast1.val]'::text, NULL::double precision);
        ELSIF upper(p_expression) = 'MIN' THEN
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, 'LEAST([rast1.val], [rast2.val])'::text, NULL::text, 'UNION'::text, '[rast2.val]'::text, '[rast1.val]'::text, NULL::double precision);
        ELSIF upper(p_expression) = 'MAX' THEN
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, 'GREATEST([rast1.val], [rast2.val])'::text, NULL::text, 'UNION'::text, '[rast2.val]'::text, '[rast1.val]'::text, NULL::double precision);
        ELSIF upper(p_expression) = 'COUNT' THEN
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, '[rast1.val] + 1'::text, NULL::text, 'UNION'::text, '1'::text, '[rast1.val]'::text, 0::double precision);
        ELSIF upper(p_expression) = 'SUM' THEN
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, '[rast1.val] + [rast2.val]'::text, NULL::text, 'UNION'::text, '[rast2.val]'::text, '[rast1.val]'::text, NULL::double precision);
        ELSIF upper(p_expression) = 'RANGE' THEN
        -- have no idea what this is 
            t_raster = ST_MapAlgebraExpr(rast1, 2, rast2, 1, 'LEAST([rast1.val], [rast2.val])'::text, NULL::text, 'UNION'::text, '[rast2.val]'::text, '[rast1.val]'::text, NULL::double precision);
            p_raster := _ST_MapAlgebra4UnionState(rast1, rast2, 'MAX'::text, NULL::text, NULL::text, NULL::double precision, NULL::text, NULL::text, NULL::text, NULL::double precision);
            RETURN ST_AddBand(p_raster, t_raster, 1, 2);
        ELSIF upper(p_expression) = 'MEAN' THEN
        -- looks like t_raster is used to keep track of accumulated count
        -- and p_raster is there to keep track of accumulated sum and final state function
        -- would then do a final map to divide them.  This one is currently broken because 
        	-- have not reworked it so it can do without a final function
            t_raster = ST_MapAlgebraExpr(rast1, 2, rast2, 1, '[rast1.val] + 1'::text, NULL::text, 'UNION'::text, '1'::text, '[rast1.val]'::text, 0::double precision);
            p_raster := _ST_MapAlgebra4UnionState(rast1, rast2, 'SUM'::text, NULL::text, NULL::text, NULL::double precision, NULL::text, NULL::text, NULL::text, NULL::double precision);
            RETURN ST_AddBand(p_raster, t_raster, 1, 2);
        ELSE
            IF t_expression NOTNULL AND t_expression != '' THEN
                t_raster = ST_MapAlgebraExpr(rast1, 2, rast2, 1, t_expression, NULL::text, 'UNION'::text, t_nodata1expr, t_nodata2expr, t_nodatanodataval::double precision);
                p_raster = ST_MapAlgebraExpr(rast1, 1, rast2, 1, p_expression, NULL::text, 'UNION'::text, p_nodata1expr, p_nodata2expr, p_nodatanodataval::double precision);
                RETURN ST_AddBand(p_raster, t_raster, 1, 2);
            END IF;
            RETURN ST_MapAlgebraExpr(rast1, 1, rast2, 1, p_expression, NULL, 'UNION'::text, NULL::text, NULL::text, NULL::double precision);
        END IF;
    END;
    $$;


ALTER FUNCTION public._st_mapalgebra4unionstate(rast1 public.raster, rast2 public.raster, p_expression text, p_nodata1expr text, p_nodata2expr text, p_nodatanodataval double precision, t_expression text, t_nodata1expr text, t_nodata2expr text, t_nodatanodataval double precision) OWNER TO postgres;

--
-- TOC entry 1889 (class 1255 OID 32382)
-- Name: _st_slope4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_slope4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        pwidth float;
        pheight float;
        dz_dx float;
        dz_dy float;
    BEGIN
        pwidth := args[1]::float;
        pheight := args[2]::float;
        dz_dx := ((matrix[3][1] + 2.0 * matrix[3][2] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[1][2] + matrix[1][3])) / (8.0 * pwidth);
        dz_dy := ((matrix[1][3] + 2.0 * matrix[2][3] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[2][1] + matrix[3][1])) / (8.0 * pheight);
        RETURN atan(sqrt(pow(dz_dx, 2.0) + pow(dz_dy, 2.0)));
    END;
    $$;


ALTER FUNCTION public._st_slope4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- TOC entry 1890 (class 1255 OID 32384)
-- Name: cleangeometry(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cleangeometry(public.geometry) RETURNS public.geometry
    LANGUAGE plpgsql
    AS $_$DECLARE
  inGeom ALIAS for $1;
  outGeom geometry;
  tmpLinestring geometry;

Begin
  
  outGeom := NULL;
  
  IF (GeometryType(inGeom) = 'POLYGON' OR GeometryType(inGeom) = 'MULTIPOLYGON') THEN

    if not isValid(inGeom) THEN
    
      tmpLinestring := st_union(st_multi(st_boundary(inGeom)),st_pointn(boundary(inGeom),1));
      outGeom = buildarea(tmpLinestring);      
      IF (GeometryType(inGeom) = 'MULTIPOLYGON') THEN      
        RETURN st_multi(outGeom);
      ELSE
        RETURN outGeom;
      END IF;
    else    
      RETURN inGeom;
    END IF;


  ELSIF (GeometryType(inGeom) = 'LINESTRING') THEN
    
    outGeom := st_union(st_multi(inGeom),st_pointn(inGeom,1));
    RETURN outGeom;
  ELSIF (GeometryType(inGeom) = 'MULTILINESTRING') THEN 
    outGeom := multi(st_union(st_multi(inGeom),st_pointn(inGeom,1)));
    RETURN outGeom;
  ELSE 
    RAISE NOTICE 'The input type % is not supported',GeometryType(inGeom);
    RETURN inGeom;
  END IF;	  
End;$_$;


ALTER FUNCTION public.cleangeometry(public.geometry) OWNER TO postgres;

--
-- TOC entry 1891 (class 1255 OID 32389)
-- Name: postgis_topology_scripts_installed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_topology_scripts_installed() RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT '2.0.1'::text || ' r' || 9979::text AS version $$;


ALTER FUNCTION public.postgis_topology_scripts_installed() OWNER TO postgres;

--
-- TOC entry 1892 (class 1255 OID 32390)
-- Name: st_addband(public.raster, public.raster[], integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_addband(torast public.raster, fromrasts public.raster[], fromband integer DEFAULT 1) RETURNS public.raster
    LANGUAGE plpgsql
    AS $$
	DECLARE var_result raster := torast;
		var_num integer := array_upper(fromrasts,1);
		var_i integer := 1; 
	BEGIN 
		IF torast IS NULL AND var_num > 0 THEN
			var_result := ST_Band(fromrasts[1],fromband); 
			var_i := 2;
		END IF;
		WHILE var_i <= var_num LOOP
			var_result := ST_AddBand(var_result, fromrasts[var_i], 1);
			var_i := var_i + 1;
		END LOOP;
		
		RETURN var_result;
	END;
$$;


ALTER FUNCTION public.st_addband(torast public.raster, fromrasts public.raster[], fromband integer) OWNER TO postgres;

--
-- TOC entry 1893 (class 1255 OID 32392)
-- Name: st_asgml(integer, public.geography, integer, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_asgml(version integer, geog public.geography, maxdecimaldigits integer DEFAULT 15, options integer DEFAULT 0, nprefix text DEFAULT NULL::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT _ST_AsGML($1, $2, $3, $4, $5);$_$;


ALTER FUNCTION public.st_asgml(version integer, geog public.geography, maxdecimaldigits integer, options integer, nprefix text) OWNER TO postgres;

--
-- TOC entry 1894 (class 1255 OID 32393)
-- Name: st_asgml(integer, public.geometry, integer, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_asgml(version integer, geom public.geometry, maxdecimaldigits integer DEFAULT 15, options integer DEFAULT 0, nprefix text DEFAULT NULL::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT _ST_AsGML($1, $2, $3, $4,$5); $_$;


ALTER FUNCTION public.st_asgml(version integer, geom public.geometry, maxdecimaldigits integer, options integer, nprefix text) OWNER TO postgres;

--
-- TOC entry 1895 (class 1255 OID 32394)
-- Name: st_aslatlontext(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_aslatlontext(public.geometry) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsLatLonText($1, '') $_$;


ALTER FUNCTION public.st_aslatlontext(public.geometry) OWNER TO postgres;

--
-- TOC entry 1896 (class 1255 OID 32395)
-- Name: st_aspect(public.raster, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_aspect(rast public.raster, band integer, pixeltype text) RETURNS public.raster
    LANGUAGE sql STABLE
    AS $_$ SELECT st_mapalgebrafctngb($1, $2, $3, 1, 1, '_st_aspect4ma(float[][], text, text[])'::regprocedure, 'value', st_pixelwidth($1)::text, st_pixelheight($1)::text) $_$;


ALTER FUNCTION public.st_aspect(rast public.raster, band integer, pixeltype text) OWNER TO postgres;

--
-- TOC entry 1897 (class 1255 OID 32396)
-- Name: st_clip(public.raster, integer, public.geometry, double precision[], boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_clip(rast public.raster, band integer, geom public.geometry, nodataval double precision[] DEFAULT NULL::double precision[], crop boolean DEFAULT true) RETURNS public.raster
    LANGUAGE plpgsql STABLE
    AS $$
	DECLARE
		newrast raster;
		geomrast raster;
		numband int;
		bandstart int;
		bandend int;
		newextent text;
		newnodataval double precision;
		newpixtype text;
		bandi int;
	BEGIN
		IF rast IS NULL THEN
			RETURN NULL;
		END IF;
		IF geom IS NULL THEN
			RETURN rast;
		END IF;
		numband := ST_Numbands(rast);
		IF band IS NULL THEN
			bandstart := 1;
			bandend := numband;
		ELSEIF ST_HasNoBand(rast, band) THEN
			RAISE NOTICE 'Raster do not have band %. Returning null', band;
			RETURN NULL;
		ELSE
			bandstart := band;
			bandend := band;
		END IF;

		newpixtype := ST_BandPixelType(rast, bandstart);
		newnodataval := coalesce(nodataval[1], ST_BandNodataValue(rast, bandstart), ST_MinPossibleValue(newpixtype));
		newextent := CASE WHEN crop THEN 'INTERSECTION' ELSE 'FIRST' END;

		-- Convert the geometry to a raster
		geomrast := ST_AsRaster(geom, rast, ST_BandPixelType(rast, band), 1, newnodataval);

		-- Compute the first raster band
		newrast := ST_MapAlgebraExpr(rast, bandstart, geomrast, 1, '[rast1.val]', newpixtype, newextent, newnodataval::text, newnodataval::text, newnodataval);
		-- Set the newnodataval
		newrast := ST_SetBandNodataValue(newrast, bandstart, newnodataval);

		FOR bandi IN bandstart+1..bandend LOOP
			-- for each band we must determine the nodata value
			newpixtype := ST_BandPixelType(rast, bandi);
			newnodataval := coalesce(nodataval[bandi], nodataval[array_upper(nodataval, 1)], ST_BandNodataValue(rast, bandi), ST_MinPossibleValue(newpixtype));
			newrast := ST_AddBand(newrast, ST_MapAlgebraExpr(rast, bandi, geomrast, 1, '[rast1.val]', newpixtype, newextent, newnodataval::text, newnodataval::text, newnodataval));
			newrast := ST_SetBandNodataValue(newrast, bandi, newnodataval);
		END LOOP;

		RETURN newrast;
	END;
	$$;


ALTER FUNCTION public.st_clip(rast public.raster, band integer, geom public.geometry, nodataval double precision[], crop boolean) OWNER TO postgres;

--
-- TOC entry 1898 (class 1255 OID 32398)
-- Name: st_hillshade(public.raster, integer, text, double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_hillshade(rast public.raster, band integer, pixeltype text, azimuth double precision, altitude double precision, max_bright double precision DEFAULT 255.0, elevation_scale double precision DEFAULT 1.0) RETURNS public.raster
    LANGUAGE sql STABLE
    AS $_$ SELECT st_mapalgebrafctngb($1, $2, $3, 1, 1, '_st_hillshade4ma(float[][], text, text[])'::regprocedure, 'value', st_pixelwidth($1)::text, st_pixelheight($1)::text, $4::text, $5::text, $6::text, $7::text) $_$;


ALTER FUNCTION public.st_hillshade(rast public.raster, band integer, pixeltype text, azimuth double precision, altitude double precision, max_bright double precision, elevation_scale double precision) OWNER TO postgres;

--
-- TOC entry 1899 (class 1255 OID 32399)
-- Name: st_pixelaspolygons(public.raster, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_pixelaspolygons(rast public.raster, band integer DEFAULT 1, OUT geom public.geometry, OUT val double precision, OUT x integer, OUT y integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
    DECLARE
        rast alias for $1;
        var_w integer;
        var_h integer;
        var_x integer;
        var_y integer;
        value float8 := NULL;
        hasband boolean := TRUE;
    BEGIN
        IF rast IS NOT NULL AND NOT ST_IsEmpty(rast) THEN
            IF ST_HasNoBand(rast, band) THEN
                RAISE NOTICE 'Raster do not have band %. Returning null values', band;
                hasband := false;
            END IF;
            SELECT ST_Width(rast), ST_Height(rast) INTO var_w, var_h;
            FOR var_x IN 1..var_w LOOP
                FOR var_y IN 1..var_h LOOP
                    IF hasband THEN
                        value := ST_Value(rast, band, var_x, var_y);
                    END IF;
                    SELECT ST_PixelAsPolygon(rast, var_x, var_y), value, var_x, var_y INTO geom,val,x,y;
                    RETURN NEXT;
                END LOOP;
            END LOOP;
        END IF;
        RETURN;
    END;
    $_$;


ALTER FUNCTION public.st_pixelaspolygons(rast public.raster, band integer, OUT geom public.geometry, OUT val double precision, OUT x integer, OUT y integer) OWNER TO postgres;

--
-- TOC entry 1900 (class 1255 OID 32400)
-- Name: st_raster2worldcoordx(public.raster, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_raster2worldcoordx(rast public.raster, xr integer) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT longitude FROM _st_raster2worldcoord($1, $2, NULL) $_$;


ALTER FUNCTION public.st_raster2worldcoordx(rast public.raster, xr integer) OWNER TO postgres;

--
-- TOC entry 1901 (class 1255 OID 32401)
-- Name: st_raster2worldcoordx(public.raster, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_raster2worldcoordx(rast public.raster, xr integer, yr integer) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT longitude FROM _st_raster2worldcoord($1, $2, $3) $_$;


ALTER FUNCTION public.st_raster2worldcoordx(rast public.raster, xr integer, yr integer) OWNER TO postgres;

--
-- TOC entry 1902 (class 1255 OID 32402)
-- Name: st_raster2worldcoordy(public.raster, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_raster2worldcoordy(rast public.raster, yr integer) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT latitude FROM _st_raster2worldcoord($1, NULL, $2) $_$;


ALTER FUNCTION public.st_raster2worldcoordy(rast public.raster, yr integer) OWNER TO postgres;

--
-- TOC entry 1903 (class 1255 OID 32403)
-- Name: st_raster2worldcoordy(public.raster, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_raster2worldcoordy(rast public.raster, xr integer, yr integer) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT latitude FROM _st_raster2worldcoord($1, $2, $3) $_$;


ALTER FUNCTION public.st_raster2worldcoordy(rast public.raster, xr integer, yr integer) OWNER TO postgres;

--
-- TOC entry 1904 (class 1255 OID 32405)
-- Name: st_resample(public.raster, integer, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_resample(rast public.raster, srid integer DEFAULT NULL::integer, scalex double precision DEFAULT 0, scaley double precision DEFAULT 0, gridx double precision DEFAULT NULL::double precision, gridy double precision DEFAULT NULL::double precision, skewx double precision DEFAULT 0, skewy double precision DEFAULT 0, algorithm text DEFAULT 'NearestNeighbour'::text, maxerr double precision DEFAULT 0.125) RETURNS public.raster
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_resample($1, $9,	$10, $2, $3, $4, $5, $6, $7, $8) $_$;


ALTER FUNCTION public.st_resample(rast public.raster, srid integer, scalex double precision, scaley double precision, gridx double precision, gridy double precision, skewx double precision, skewy double precision, algorithm text, maxerr double precision) OWNER TO postgres;

--
-- TOC entry 1905 (class 1255 OID 32406)
-- Name: st_resample(public.raster, integer, integer, integer, double precision, double precision, double precision, double precision, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_resample(rast public.raster, width integer, height integer, srid integer DEFAULT NULL::integer, gridx double precision DEFAULT NULL::double precision, gridy double precision DEFAULT NULL::double precision, skewx double precision DEFAULT 0, skewy double precision DEFAULT 0, algorithm text DEFAULT 'NearestNeighbour'::text, maxerr double precision DEFAULT 0.125) RETURNS public.raster
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_resample($1, $9,	$10, $4, NULL, NULL, $5, $6, $7, $8, $2, $3) $_$;


ALTER FUNCTION public.st_resample(rast public.raster, width integer, height integer, srid integer, gridx double precision, gridy double precision, skewx double precision, skewy double precision, algorithm text, maxerr double precision) OWNER TO postgres;

--
-- TOC entry 1906 (class 1255 OID 32407)
-- Name: st_slope(public.raster, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_slope(rast public.raster, band integer, pixeltype text) RETURNS public.raster
    LANGUAGE sql STABLE
    AS $_$ SELECT st_mapalgebrafctngb($1, $2, $3, 1, 1, '_st_slope4ma(float[][], text, text[])'::regprocedure, 'value', st_pixelwidth($1)::text, st_pixelheight($1)::text) $_$;


ALTER FUNCTION public.st_slope(rast public.raster, band integer, pixeltype text) OWNER TO postgres;

--
-- TOC entry 1907 (class 1255 OID 32408)
-- Name: st_world2rastercoordx(public.raster, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_world2rastercoordx(rast public.raster, xw double precision) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT columnx FROM _st_world2rastercoord($1, $2, NULL) $_$;


ALTER FUNCTION public.st_world2rastercoordx(rast public.raster, xw double precision) OWNER TO postgres;

--
-- TOC entry 1908 (class 1255 OID 32409)
-- Name: st_world2rastercoordx(public.raster, public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_world2rastercoordx(rast public.raster, pt public.geometry) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
	DECLARE
		xr integer;
	BEGIN
		IF ( st_geometrytype(pt) != 'ST_Point' ) THEN
			RAISE EXCEPTION 'Attempting to compute raster coordinate with a non-point geometry';
		END IF;
		SELECT columnx INTO xr FROM _st_world2rastercoord($1, st_x(pt), st_y(pt));
		RETURN xr;
	END;
	$_$;


ALTER FUNCTION public.st_world2rastercoordx(rast public.raster, pt public.geometry) OWNER TO postgres;

--
-- TOC entry 1909 (class 1255 OID 32410)
-- Name: st_world2rastercoordx(public.raster, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_world2rastercoordx(rast public.raster, xw double precision, yw double precision) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT columnx FROM _st_world2rastercoord($1, $2, $3) $_$;


ALTER FUNCTION public.st_world2rastercoordx(rast public.raster, xw double precision, yw double precision) OWNER TO postgres;

--
-- TOC entry 1879 (class 1255 OID 32411)
-- Name: st_world2rastercoordy(public.raster, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_world2rastercoordy(rast public.raster, yw double precision) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT rowy FROM _st_world2rastercoord($1, NULL, $2) $_$;


ALTER FUNCTION public.st_world2rastercoordy(rast public.raster, yw double precision) OWNER TO postgres;

--
-- TOC entry 1880 (class 1255 OID 32412)
-- Name: st_world2rastercoordy(public.raster, public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_world2rastercoordy(rast public.raster, pt public.geometry) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
	DECLARE
		yr integer;
	BEGIN
		IF ( st_geometrytype(pt) != 'ST_Point' ) THEN
			RAISE EXCEPTION 'Attempting to compute raster coordinate with a non-point geometry';
		END IF;
		SELECT rowy INTO yr FROM _st_world2rastercoord($1, st_x(pt), st_y(pt));
		RETURN yr;
	END;
	$_$;


ALTER FUNCTION public.st_world2rastercoordy(rast public.raster, pt public.geometry) OWNER TO postgres;

--
-- TOC entry 1881 (class 1255 OID 32413)
-- Name: st_world2rastercoordy(public.raster, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_world2rastercoordy(rast public.raster, xw double precision, yw double precision) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT rowy FROM _st_world2rastercoord($1, $2, $3) $_$;


ALTER FUNCTION public.st_world2rastercoordy(rast public.raster, xw double precision, yw double precision) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 264 (class 1259 OID 32414)
-- Name: Ctr_Pesaro_5000; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Ctr_Pesaro_5000" (
    gid integer NOT NULL,
    the_geom public.geometry(LineString,3004),
    "Layer" character varying,
    "SubClasses" character varying,
    "ExtendedEntity" character varying,
    "Linetype" character varying,
    "EntityHandle" character varying,
    "Text" character varying
);


ALTER TABLE public."Ctr_Pesaro_5000" OWNER TO postgres;

--
-- TOC entry 265 (class 1259 OID 32420)
-- Name: Ctr_Pesaro_5000_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Ctr_Pesaro_5000_gid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."Ctr_Pesaro_5000_gid_seq" OWNER TO postgres;

--
-- TOC entry 5012 (class 0 OID 0)
-- Dependencies: 265
-- Name: Ctr_Pesaro_5000_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Ctr_Pesaro_5000_gid_seq" OWNED BY public."Ctr_Pesaro_5000".gid;


--
-- TOC entry 266 (class 1259 OID 32422)
-- Name: archeozoology_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.archeozoology_table (
    id_archzoo integer NOT NULL,
    sito text,
    area text,
    us integer,
    quadrato text,
    coord_x integer,
    coord_y integer,
    bos_bison integer,
    calcinati integer,
    camoscio integer,
    capriolo integer,
    cervo integer,
    combusto integer,
    coni integer,
    pdi integer,
    stambecco integer,
    strie integer,
    canidi integer,
    ursidi integer,
    megacero integer
);


ALTER TABLE public.archeozoology_table OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 32428)
-- Name: archeozoology_table_id_archzoo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.archeozoology_table_id_archzoo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.archeozoology_table_id_archzoo_seq OWNER TO postgres;

--
-- TOC entry 5013 (class 0 OID 0)
-- Dependencies: 267
-- Name: archeozoology_table_id_archzoo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.archeozoology_table_id_archzoo_seq OWNED BY public.archeozoology_table.id_archzoo;


--
-- TOC entry 442 (class 1259 OID 107435)
-- Name: bf_battle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bf_battle (
    id_battle_pk integer NOT NULL,
    place text NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.bf_battle OWNER TO postgres;

--
-- TOC entry 441 (class 1259 OID 107433)
-- Name: bf_battle_id_battle_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bf_battle_id_battle_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bf_battle_id_battle_pk_seq OWNER TO postgres;

--
-- TOC entry 5014 (class 0 OID 0)
-- Dependencies: 441
-- Name: bf_battle_id_battle_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bf_battle_id_battle_pk_seq OWNED BY public.bf_battle.id_battle_pk;


--
-- TOC entry 438 (class 1259 OID 107411)
-- Name: bf_camp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bf_camp (
    id_camp_pk integer NOT NULL,
    army_name text,
    place_name text,
    date date,
    sequence integer NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.bf_camp OWNER TO postgres;

--
-- TOC entry 437 (class 1259 OID 107409)
-- Name: bf_camp_id_camp_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bf_camp_id_camp_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bf_camp_id_camp_pk_seq OWNER TO postgres;

--
-- TOC entry 5015 (class 0 OID 0)
-- Dependencies: 437
-- Name: bf_camp_id_camp_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bf_camp_id_camp_pk_seq OWNED BY public.bf_camp.id_camp_pk;


--
-- TOC entry 440 (class 1259 OID 107423)
-- Name: bf_displacement; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bf_displacement (
    id_displacement_pk integer NOT NULL,
    army_name text NOT NULL,
    id_start_camp_fk integer NOT NULL,
    id_arrival_camp_fk integer NOT NULL,
    date date,
    geom public.geometry(LineString,3004)
);


ALTER TABLE public.bf_displacement OWNER TO postgres;

--
-- TOC entry 439 (class 1259 OID 107421)
-- Name: bf_displacement_id_displacement_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bf_displacement_id_displacement_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bf_displacement_id_displacement_pk_seq OWNER TO postgres;

--
-- TOC entry 5016 (class 0 OID 0)
-- Dependencies: 439
-- Name: bf_displacement_id_displacement_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bf_displacement_id_displacement_pk_seq OWNED BY public.bf_displacement.id_displacement_pk;


--
-- TOC entry 456 (class 1259 OID 230503)
-- Name: biblio_id_biblio_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.biblio_id_biblio_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.biblio_id_biblio_pk_seq OWNER TO postgres;

--
-- TOC entry 457 (class 1259 OID 230505)
-- Name: biblio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.biblio (
    id_biblio_pk integer DEFAULT nextval('public.biblio_id_biblio_pk_seq'::regclass) NOT NULL,
    id_biblio character varying,
    titolo character varying,
    anno integer,
    rif_misc character varying,
    indicazione_responsabile text,
    anno_letterale text,
    nome_resp text,
    pagine text
);


ALTER TABLE public.biblio OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 32430)
-- Name: campioni_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campioni_table (
    id_campione integer NOT NULL,
    sito text,
    nr_campione integer,
    tipo_campione text,
    descrizione text,
    area character varying(4),
    us integer,
    numero_inventario_materiale integer,
    nr_cassa integer,
    luogo_conservazione text
);


ALTER TABLE public.campioni_table OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 32436)
-- Name: campioni_table_id_campione_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.campioni_table_id_campione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campioni_table_id_campione_seq OWNER TO postgres;

--
-- TOC entry 5017 (class 0 OID 0)
-- Dependencies: 269
-- Name: campioni_table_id_campione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.campioni_table_id_campione_seq OWNED BY public.campioni_table.id_campione;


--
-- TOC entry 270 (class 1259 OID 32438)
-- Name: canonica; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.canonica (
    gid integer NOT NULL,
    id integer,
    fshape text,
    entity text,
    layer text,
    color integer,
    elevation double precision,
    thickness double precision,
    text text,
    heighttext double precision,
    rotationtext double precision,
    the_geom public.geometry(Geometry,3004),
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.canonica OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 32446)
-- Name: canonica_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.canonica_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.canonica_gid_seq OWNER TO postgres;

--
-- TOC entry 5018 (class 0 OID 0)
-- Dependencies: 271
-- Name: canonica_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.canonica_gid_seq OWNED BY public.canonica.gid;


--
-- TOC entry 272 (class 1259 OID 32448)
-- Name: carta_archeologica_mansuelli; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.carta_archeologica_mansuelli (
    gid integer NOT NULL,
    id_numero integer,
    id_lettera character varying(10),
    definizion character varying(250),
    denominazi character varying(250),
    descrizion character varying(250),
    pagina integer,
    parte character varying(100),
    the_geom public.geometry,
    test smallint,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.carta_archeologica_mansuelli OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 32457)
-- Name: carta_archeologica_mansuelli_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.carta_archeologica_mansuelli_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.carta_archeologica_mansuelli_gid_seq OWNER TO postgres;

--
-- TOC entry 5019 (class 0 OID 0)
-- Dependencies: 273
-- Name: carta_archeologica_mansuelli_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.carta_archeologica_mansuelli_gid_seq OWNED BY public.carta_archeologica_mansuelli.gid;


--
-- TOC entry 274 (class 1259 OID 32459)
-- Name: casto_calindri_particelle_pre_convegno; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.casto_calindri_particelle_pre_convegno (
    gid integer NOT NULL,
    nr_territo integer,
    nrpart integer,
    nrpartbis character varying(100),
    nr_mappa integer,
    "Settore te" character varying(100),
    the_geom public.geometry,
    "tipo_proprietà" character varying DEFAULT 'privato'::character varying,
    titolo_proprietario character varying DEFAULT 'illustrissimo capitano'::character varying,
    nome character varying,
    cognome character varying,
    colonna_1 integer,
    colonna_2 integer,
    colonna_3 integer,
    note character varying,
    contrada character varying,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.casto_calindri_particelle_pre_convegno OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 32470)
-- Name: casto_calindri_particelle_pre_convegno_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.casto_calindri_particelle_pre_convegno_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.casto_calindri_particelle_pre_convegno_gid_seq OWNER TO postgres;

--
-- TOC entry 5020 (class 0 OID 0)
-- Dependencies: 275
-- Name: casto_calindri_particelle_pre_convegno_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.casto_calindri_particelle_pre_convegno_gid_seq OWNED BY public.casto_calindri_particelle_pre_convegno.gid;


--
-- TOC entry 276 (class 1259 OID 32472)
-- Name: catastale_regione_marche_R11_11; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."catastale_regione_marche_R11_11" (
    gid integer NOT NULL,
    the_geom public.geometry(MultiPolygon,3004),
    cod_istat integer,
    pro_com integer,
    sez2011 double precision,
    sez integer,
    cod_stagno integer,
    cod_fiume integer,
    cod_lago integer,
    cod_laguna integer,
    cod_val_p integer,
    cod_zona_c integer,
    cod_is_amm integer,
    cod_is_lac integer,
    cod_is_mar integer,
    cod_area_s integer,
    cod_mont_d integer,
    loc2011 numeric,
    cod_loc integer,
    tipo_loc integer,
    shape_leng numeric,
    shape_le_1 numeric,
    shape_area numeric
);


ALTER TABLE public."catastale_regione_marche_R11_11" OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 32478)
-- Name: catastale_regione_marche_R11_11_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."catastale_regione_marche_R11_11_gid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."catastale_regione_marche_R11_11_gid_seq" OWNER TO postgres;

--
-- TOC entry 5021 (class 0 OID 0)
-- Dependencies: 277
-- Name: catastale_regione_marche_R11_11_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."catastale_regione_marche_R11_11_gid_seq" OWNED BY public."catastale_regione_marche_R11_11".gid;


--
-- TOC entry 278 (class 1259 OID 32480)
-- Name: catasto_calindri_comuni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_calindri_comuni (
    gid integer NOT NULL,
    "GID2" integer,
    "FRAZIONE" character varying(255),
    "MAPPA" integer,
    "TERRITORIO" character varying(255),
    "COMUNI" character varying(50),
    "CDISTAT" integer,
    "NR_FRAZION" double precision,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.catasto_calindri_comuni OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 32489)
-- Name: catasto_calindri_comuni_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_calindri_comuni_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_calindri_comuni_gid_seq OWNER TO postgres;

--
-- TOC entry 5022 (class 0 OID 0)
-- Dependencies: 279
-- Name: catasto_calindri_comuni_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_calindri_comuni_gid_seq OWNED BY public.catasto_calindri_comuni.gid;


--
-- TOC entry 280 (class 1259 OID 32491)
-- Name: catasto_calindri_particelle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_calindri_particelle (
    gid2 integer NOT NULL,
    gid integer,
    nr_territo integer,
    nrpart integer,
    nrpartbis character varying(100),
    nr_mappa integer,
    "Settore te" character varying(100),
    tipo_propr character varying(255),
    titolo_pro character varying(255),
    nome character varying(255),
    cognome character varying(255),
    colonna_1 integer,
    colonna_2 integer,
    colonna_3 integer,
    note character varying(255),
    contrada character varying(255),
    the_geom public.geometry(Point,3004)
);


ALTER TABLE public.catasto_calindri_particelle OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 32497)
-- Name: catasto_calindri_particelle_gid2_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_calindri_particelle_gid2_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_calindri_particelle_gid2_seq OWNER TO postgres;

--
-- TOC entry 5023 (class 0 OID 0)
-- Dependencies: 281
-- Name: catasto_calindri_particelle_gid2_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_calindri_particelle_gid2_seq OWNED BY public.catasto_calindri_particelle.gid2;


--
-- TOC entry 282 (class 1259 OID 32499)
-- Name: catasto_calindri_per_comuni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_calindri_per_comuni (
    gid integer NOT NULL,
    "FRAZIONE" character varying(80),
    "MAPPA" integer,
    "TERRITORIO" character varying(80),
    "COMUNE" character varying(25),
    "NR_FRAZION" integer,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.catasto_calindri_per_comuni OWNER TO postgres;

--
-- TOC entry 283 (class 1259 OID 32508)
-- Name: catasto_calindri_per_comuni_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_calindri_per_comuni_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_calindri_per_comuni_gid_seq OWNER TO postgres;

--
-- TOC entry 5024 (class 0 OID 0)
-- Dependencies: 283
-- Name: catasto_calindri_per_comuni_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_calindri_per_comuni_gid_seq OWNED BY public.catasto_calindri_per_comuni.gid;


--
-- TOC entry 284 (class 1259 OID 32510)
-- Name: catasto_calindri_per_localita; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_calindri_per_localita (
    gid integer NOT NULL,
    "GID2" integer,
    "FRAZIONE" character varying(255),
    "TERRITORIO" character varying(255),
    "NR_FRAZION" integer,
    the_geom public.geometry(MultiPolygon),
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.catasto_calindri_per_localita OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 32518)
-- Name: catasto_calindri_per_localita_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_calindri_per_localita_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_calindri_per_localita_gid_seq OWNER TO postgres;

--
-- TOC entry 5025 (class 0 OID 0)
-- Dependencies: 285
-- Name: catasto_calindri_per_localita_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_calindri_per_localita_gid_seq OWNED BY public.catasto_calindri_per_localita.gid;


--
-- TOC entry 286 (class 1259 OID 32520)
-- Name: catasto_calindri_toponimo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_calindri_toponimo (
    gid integer NOT NULL,
    "TOPONIMO" character varying(150),
    "NR_TERRITO" integer,
    "NR_MAPPA_V" integer,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.catasto_calindri_toponimo OWNER TO postgres;

--
-- TOC entry 287 (class 1259 OID 32529)
-- Name: catasto_calindri_toponimo_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_calindri_toponimo_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_calindri_toponimo_gid_seq OWNER TO postgres;

--
-- TOC entry 5026 (class 0 OID 0)
-- Dependencies: 287
-- Name: catasto_calindri_toponimo_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_calindri_toponimo_gid_seq OWNED BY public.catasto_calindri_toponimo.gid;


--
-- TOC entry 288 (class 1259 OID 32531)
-- Name: catasto_fano_2000_22; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_fano_2000_22 (
    id integer NOT NULL,
    geom public.geometry(LineString,3004),
    "Layer" character varying,
    "SubClasses" character varying,
    "ExtendedEntity" character varying,
    "Linetype" character varying,
    "EntityHandle" character varying,
    "Text" character varying
);


ALTER TABLE public.catasto_fano_2000_22 OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 32537)
-- Name: catasto_fano_2000_22_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_fano_2000_22_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_fano_2000_22_id_seq OWNER TO postgres;

--
-- TOC entry 5027 (class 0 OID 0)
-- Dependencies: 289
-- Name: catasto_fano_2000_22_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_fano_2000_22_id_seq OWNED BY public.catasto_fano_2000_22.id;


--
-- TOC entry 290 (class 1259 OID 32539)
-- Name: catasto_test; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catasto_test (
    gid2 integer NOT NULL,
    gid integer,
    nr_territo integer,
    nrpart integer,
    nrpartbis character varying(255),
    nr_mappa integer,
    "Settore te" character varying(255),
    tipo_propr character varying(255),
    titolo_pro character varying(255),
    nome character varying(255),
    cognome character varying(255),
    colonna_1 integer,
    colonna_2 integer,
    colonna_3 integer,
    note character varying(255),
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.catasto_test OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 32548)
-- Name: catasto_test_gid2_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catasto_test_gid2_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.catasto_test_gid2_seq OWNER TO postgres;

--
-- TOC entry 5028 (class 0 OID 0)
-- Dependencies: 291
-- Name: catasto_test_gid2_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catasto_test_gid2_seq OWNED BY public.catasto_test.gid2;


--
-- TOC entry 292 (class 1259 OID 32550)
-- Name: conversione_geo_cpa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.conversione_geo_cpa (
    cod_geo character varying,
    color character varying,
    descrizione character varying,
    id_conversione integer NOT NULL
);


ALTER TABLE public.conversione_geo_cpa OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 32556)
-- Name: conversione_geo_cpa_id_conversione_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conversione_geo_cpa_id_conversione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.conversione_geo_cpa_id_conversione_seq OWNER TO postgres;

--
-- TOC entry 5029 (class 0 OID 0)
-- Dependencies: 293
-- Name: conversione_geo_cpa_id_conversione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.conversione_geo_cpa_id_conversione_seq OWNED BY public.conversione_geo_cpa.id_conversione;


--
-- TOC entry 428 (class 1259 OID 82763)
-- Name: covignano_open_park_siti; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.covignano_open_park_siti (
    id_cop integer NOT NULL,
    nome text NOT NULL,
    datazione text NOT NULL,
    tipo_sito text NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.covignano_open_park_siti OWNER TO postgres;

--
-- TOC entry 427 (class 1259 OID 82761)
-- Name: covignano_open_park_siti_id_cop_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.covignano_open_park_siti_id_cop_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.covignano_open_park_siti_id_cop_seq OWNER TO postgres;

--
-- TOC entry 5030 (class 0 OID 0)
-- Dependencies: 427
-- Name: covignano_open_park_siti_id_cop_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.covignano_open_park_siti_id_cop_seq OWNED BY public.covignano_open_park_siti.id_cop;


--
-- TOC entry 294 (class 1259 OID 32558)
-- Name: ctr_provincia_pesaro_urbino_epsg3004; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ctr_provincia_pesaro_urbino_epsg3004 (
    gid integer NOT NULL,
    the_geom public.geometry(MultiLineString,3004),
    id integer
);


ALTER TABLE public.ctr_provincia_pesaro_urbino_epsg3004 OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 32564)
-- Name: ctr_provincia_pesaro_urbino_epsg3004_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ctr_provincia_pesaro_urbino_epsg3004_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ctr_provincia_pesaro_urbino_epsg3004_gid_seq OWNER TO postgres;

--
-- TOC entry 5031 (class 0 OID 0)
-- Dependencies: 295
-- Name: ctr_provincia_pesaro_urbino_epsg3004_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ctr_provincia_pesaro_urbino_epsg3004_gid_seq OWNED BY public.ctr_provincia_pesaro_urbino_epsg3004.gid;


--
-- TOC entry 450 (class 1259 OID 164931)
-- Name: dati_ambientali; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dati_ambientali (
    id_dati_amb integer NOT NULL,
    tipo_dato text NOT NULL,
    specie text NOT NULL,
    anno_ult_avvistamento integer NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.dati_ambientali OWNER TO postgres;

--
-- TOC entry 449 (class 1259 OID 164929)
-- Name: dati_ambientali_id_dati_amb_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dati_ambientali_id_dati_amb_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dati_ambientali_id_dati_amb_seq OWNER TO postgres;

--
-- TOC entry 5032 (class 0 OID 0)
-- Dependencies: 449
-- Name: dati_ambientali_id_dati_amb_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dati_ambientali_id_dati_amb_seq OWNED BY public.dati_ambientali.id_dati_amb;


--
-- TOC entry 296 (class 1259 OID 32566)
-- Name: deteta_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deteta_table (
    id_det_eta integer NOT NULL,
    sito text,
    nr_individuo integer,
    sinf_min integer,
    sinf_max integer,
    sinf_min_2 integer,
    sinf_max_2 integer,
    "SSPIA" integer,
    "SSPIB" integer,
    "SSPIC" integer,
    "SSPID" integer,
    sup_aur_min integer,
    sup_aur_max integer,
    sup_aur_min_2 integer,
    sup_aur_max_2 integer,
    ms_sup_min integer,
    ms_sup_max integer,
    ms_inf_min integer,
    ms_inf_max integer,
    usura_min integer,
    usura_max integer,
    "Id_endo" integer,
    "Is_endo" integer,
    "IId_endo" integer,
    "IIs_endo" integer,
    "IIId_endo" integer,
    "IIIs_endo" integer,
    "IV_endo" integer,
    "V_endo" integer,
    "VI_endo" integer,
    "VII_endo" integer,
    "VIIId_endo" integer,
    "VIIIs_endo" integer,
    "IXd_endo" integer,
    "IXs_endo" integer,
    "Xd_endo" integer,
    "Xs_endo" integer,
    endo_min integer,
    endo_max integer,
    volta_1 integer,
    volta_2 integer,
    volta_3 integer,
    volta_4 integer,
    volta_5 integer,
    volta_6 integer,
    volta_7 integer,
    lat_6 integer,
    lat_7 integer,
    lat_8 integer,
    lat_9 integer,
    lat_10 integer,
    volta_min integer,
    volta_max integer,
    ant_lat_min integer,
    ant_lat_max integer,
    ecto_min integer,
    ecto_max integer
);


ALTER TABLE public.deteta_table OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 32572)
-- Name: deteta_table_id_det_eta_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deteta_table_id_det_eta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deteta_table_id_det_eta_seq OWNER TO postgres;

--
-- TOC entry 5033 (class 0 OID 0)
-- Dependencies: 297
-- Name: deteta_table_id_det_eta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deteta_table_id_det_eta_seq OWNED BY public.deteta_table.id_det_eta;


--
-- TOC entry 298 (class 1259 OID 32574)
-- Name: detsesso_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detsesso_table (
    id_det_sesso integer NOT NULL,
    sito text,
    num_individuo integer,
    glab_grado_imp integer,
    pmast_grado_imp integer,
    pnuc_grado_imp integer,
    pzig_grado_imp integer,
    arcsop_grado_imp integer,
    tub_grado_imp integer,
    pocc_grado_imp integer,
    inclfr_grado_imp integer,
    zig_grado_imp integer,
    msorb_grado_imp integer,
    glab_valori integer,
    pmast_valori integer,
    pnuc_valori integer,
    pzig_valori integer,
    arcsop_valori integer,
    tub_valori integer,
    pocc_valori integer,
    inclfr_valori integer,
    zig_valori integer,
    msorb_valori integer,
    palato_grado_imp integer,
    mfmand_grado_imp integer,
    mento_grado_imp integer,
    anmand_grado_imp integer,
    minf_grado_imp integer,
    brmont_grado_imp integer,
    condm_grado_imp integer,
    palato_valori integer,
    mfmand_valori integer,
    mento_valori integer,
    anmand_valori integer,
    minf_valori integer,
    brmont_valori integer,
    condm_valori integer,
    sex_cr_tot real,
    ind_cr_sex character varying(100),
    "sup_p_I" character varying(1),
    "sup_p_II" character varying(1),
    "sup_p_III" character varying(1),
    sup_p_sex character varying(1),
    "in_isch_I" character varying(1),
    "in_isch_II" character varying(1),
    "in_isch_III" character varying(1),
    in_isch_sex character varying(1),
    arco_c_sex character varying(1),
    "ramo_ip_I" character varying(1),
    "ramo_ip_II" character varying(1),
    "ramo_ip_III" character varying(1),
    ramo_ip_sex character varying(1),
    prop_ip_sex character varying(1),
    ind_bac_sex character varying(100)
);


ALTER TABLE public.detsesso_table OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 32580)
-- Name: detsesso_table_id_det_sesso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detsesso_table_id_det_sesso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.detsesso_table_id_det_sesso_seq OWNER TO postgres;

--
-- TOC entry 5034 (class 0 OID 0)
-- Dependencies: 299
-- Name: detsesso_table_id_det_sesso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detsesso_table_id_det_sesso_seq OWNED BY public.detsesso_table.id_det_sesso;


--
-- TOC entry 300 (class 1259 OID 32582)
-- Name: diacronia_siti_cpa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.diacronia_siti_cpa (
    iddiacronia integer NOT NULL,
    periodo character varying,
    fase character varying,
    idsito character varying
);


ALTER TABLE public.diacronia_siti_cpa OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 32588)
-- Name: diacronia_siti_cpa_id_diacronia_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.diacronia_siti_cpa_id_diacronia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.diacronia_siti_cpa_id_diacronia_seq OWNER TO postgres;

--
-- TOC entry 5035 (class 0 OID 0)
-- Dependencies: 301
-- Name: diacronia_siti_cpa_id_diacronia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.diacronia_siti_cpa_id_diacronia_seq OWNED BY public.diacronia_siti_cpa.iddiacronia;


--
-- TOC entry 302 (class 1259 OID 32590)
-- Name: documentazione_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documentazione_table (
    id_documentazione integer NOT NULL,
    sito text,
    nome_doc text,
    data text,
    tipo_documentazione text,
    sorgente text,
    scala text,
    disegnatore text,
    note text
);


ALTER TABLE public.documentazione_table OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 32596)
-- Name: documentazione_table_id_documentazione_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.documentazione_table_id_documentazione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.documentazione_table_id_documentazione_seq OWNER TO postgres;

--
-- TOC entry 5036 (class 0 OID 0)
-- Dependencies: 303
-- Name: documentazione_table_id_documentazione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.documentazione_table_id_documentazione_seq OWNED BY public.documentazione_table.id_documentazione;


--
-- TOC entry 304 (class 1259 OID 32598)
-- Name: fabbricati_gbe; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fabbricati_gbe (
    gid integer NOT NULL,
    "COMUNE" character varying(4),
    "SEZIONE" character varying(1),
    "FOGLIO" character varying(4),
    "ALLEGATO" character varying(1),
    "SVILUPPO" character varying(1),
    "NUMERO" character varying(9),
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.fabbricati_gbe OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 32607)
-- Name: fano_2000_unione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fano_2000_unione (
    gid integer NOT NULL,
    the_geom public.geometry(MultiLineString,3004),
    layer character varying(254),
    subclasses character varying(254),
    extendeden character varying(254),
    linetype character varying(254),
    entityhand character varying(254),
    text character varying(254)
);


ALTER TABLE public.fano_2000_unione OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 32613)
-- Name: fano_2000_unione_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fano_2000_unione_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fano_2000_unione_gid_seq OWNER TO postgres;

--
-- TOC entry 5037 (class 0 OID 0)
-- Dependencies: 306
-- Name: fano_2000_unione_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fano_2000_unione_gid_seq OWNED BY public.fano_2000_unione.gid;


--
-- TOC entry 307 (class 1259 OID 32615)
-- Name: fano_500_centro_storico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fano_500_centro_storico (
    gid integer NOT NULL,
    the_geom public.geometry(MultiLineString,3004),
    layer character varying(254),
    subclasses character varying(254),
    extendeden character varying(254),
    linetype character varying(254),
    entityhand character varying(254),
    text character varying(254)
);


ALTER TABLE public.fano_500_centro_storico OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 32621)
-- Name: fano_500_centro_storico_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fano_500_centro_storico_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fano_500_centro_storico_gid_seq OWNER TO postgres;

--
-- TOC entry 5038 (class 0 OID 0)
-- Dependencies: 308
-- Name: fano_500_centro_storico_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fano_500_centro_storico_gid_seq OWNED BY public.fano_500_centro_storico.gid;


--
-- TOC entry 444 (class 1259 OID 115660)
-- Name: griglia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.griglia (
    id_griglia_pk integer NOT NULL,
    id_sito_fk integer,
    griglia_sigla text
);


ALTER TABLE public.griglia OWNER TO postgres;

--
-- TOC entry 443 (class 1259 OID 115658)
-- Name: griglia_id_griglia_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.griglia_id_griglia_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.griglia_id_griglia_pk_seq OWNER TO postgres;

--
-- TOC entry 5039 (class 0 OID 0)
-- Dependencies: 443
-- Name: griglia_id_griglia_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.griglia_id_griglia_pk_seq OWNED BY public.griglia.id_griglia_pk;


--
-- TOC entry 309 (class 1259 OID 32623)
-- Name: individui_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.individui_table (
    id_scheda_ind integer NOT NULL,
    sito text,
    area character varying(4),
    us integer,
    nr_individuo integer,
    data_schedatura character varying(100),
    schedatore character varying(100),
    sesso character varying(100),
    eta_min integer,
    eta_max integer,
    classi_eta character varying(100),
    osservazioni text
);


ALTER TABLE public.individui_table OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 32629)
-- Name: individui_table_id_scheda_ind_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.individui_table_id_scheda_ind_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.individui_table_id_scheda_ind_seq OWNER TO postgres;

--
-- TOC entry 5040 (class 0 OID 0)
-- Dependencies: 310
-- Name: individui_table_id_scheda_ind_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.individui_table_id_scheda_ind_seq OWNED BY public.individui_table.id_scheda_ind;


--
-- TOC entry 419 (class 1259 OID 57657)
-- Name: inventario_lapidei_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventario_lapidei_table (
    id_invlap integer NOT NULL,
    sito text,
    scheda_numero integer,
    collocazione text,
    oggetto text,
    tipologia text,
    materiale text,
    d_letto_posa numeric(4,2),
    d_letto_attesa numeric(4,2),
    toro numeric(4,2),
    spessore numeric(4,2),
    larghezza numeric(4,2),
    lunghezza numeric(4,2),
    h numeric(4,2),
    descrizione text,
    lavorazione_e_stato_di_conservazione text,
    confronti text,
    cronologia text,
    bibliografia text,
    compilatore text
);


ALTER TABLE public.inventario_lapidei_table OWNER TO postgres;

--
-- TOC entry 418 (class 1259 OID 57655)
-- Name: inventario_lapidei_table_id_invlap_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventario_lapidei_table_id_invlap_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inventario_lapidei_table_id_invlap_seq OWNER TO postgres;

--
-- TOC entry 5041 (class 0 OID 0)
-- Dependencies: 418
-- Name: inventario_lapidei_table_id_invlap_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventario_lapidei_table_id_invlap_seq OWNED BY public.inventario_lapidei_table.id_invlap;


--
-- TOC entry 311 (class 1259 OID 32631)
-- Name: inventario_materiali_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventario_materiali_table (
    id_invmat integer NOT NULL,
    sito text,
    numero_inventario integer,
    tipo_reperto text,
    criterio_schedatura text,
    definizione text,
    descrizione text,
    area integer,
    us integer,
    lavato character varying(2),
    nr_cassa integer,
    luogo_conservazione text,
    stato_conservazione character varying DEFAULT 'inserisci un valore'::character varying,
    datazione_reperto character varying(30) DEFAULT 'inserisci un valore'::character varying,
    elementi_reperto text,
    misurazioni text,
    rif_biblio text,
    tecnologie text,
    forme_minime integer DEFAULT 0,
    forme_massime integer DEFAULT 0,
    totale_frammenti integer DEFAULT 0,
    corpo_ceramico character varying(20),
    rivestimento character varying(20),
    diametro_orlo numeric(7,3) DEFAULT 0,
    peso numeric(9,3) DEFAULT 0,
    tipo character varying(20),
    eve_orlo numeric(7,3) DEFAULT 0,
    repertato character varying(2),
    diagnostico character varying(2)
);


ALTER TABLE public.inventario_materiali_table OWNER TO postgres;

--
-- TOC entry 312 (class 1259 OID 32645)
-- Name: inventario_materiali_table_id_invmat_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventario_materiali_table_id_invmat_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inventario_materiali_table_id_invmat_seq OWNER TO postgres;

--
-- TOC entry 5042 (class 0 OID 0)
-- Dependencies: 312
-- Name: inventario_materiali_table_id_invmat_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventario_materiali_table_id_invmat_seq OWNED BY public.inventario_materiali_table.id_invmat;


--
-- TOC entry 313 (class 1259 OID 32647)
-- Name: inventario_materiali_table_toimp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventario_materiali_table_toimp (
    id_invmat integer NOT NULL,
    sito text,
    numero_inventario integer,
    tipo_reperto text,
    criterio_schedatura text,
    definizione text,
    descrizione text,
    area integer,
    us integer,
    lavato character varying(2),
    nr_cassa integer,
    luogo_conservazione text,
    stato_conservazione character varying(20),
    datazione_reperto character varying(30),
    elementi_reperto text,
    misurazioni text,
    rif_biblio text,
    tecnologie text
);


ALTER TABLE public.inventario_materiali_table_toimp OWNER TO postgres;

--
-- TOC entry 314 (class 1259 OID 32653)
-- Name: inventario_materiali_table_toimp_id_invmat_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventario_materiali_table_toimp_id_invmat_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inventario_materiali_table_toimp_id_invmat_seq OWNER TO postgres;

--
-- TOC entry 5043 (class 0 OID 0)
-- Dependencies: 314
-- Name: inventario_materiali_table_toimp_id_invmat_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventario_materiali_table_toimp_id_invmat_seq OWNED BY public.inventario_materiali_table_toimp.id_invmat;


--
-- TOC entry 315 (class 1259 OID 32655)
-- Name: ipogeo_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ipogeo_table (
    id_ipogeo integer NOT NULL,
    sito_ipogeo text,
    sigla_ipogeo text,
    numero_ipogeo integer,
    categoria_ipogeo text,
    tipologia_ipogeo text,
    definizione_ipogeo text,
    descrizione_ipogeo text,
    interpretazione_ipogeo text,
    periodo_iniziale_ipogeo integer,
    fase_iniziale_ipogeo integer,
    periodo_finale_ipogeo integer,
    fase_finale_ipogeo integer,
    datazione_estesa_ipogeo character varying(300),
    materiali_impiegati_ipogeo text,
    elementi_strutturali_ipogeo text,
    rapporti_ipogeo text,
    misure_ipogeo text,
    percentuale_umidita_ipogeo real,
    grado_conservazione_ipogeo integer,
    grado_staticita_ipogeo integer
);


ALTER TABLE public.ipogeo_table OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 32661)
-- Name: ipogeo_table_id_ipogeo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ipogeo_table_id_ipogeo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ipogeo_table_id_ipogeo_seq OWNER TO postgres;

--
-- TOC entry 5044 (class 0 OID 0)
-- Dependencies: 316
-- Name: ipogeo_table_id_ipogeo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ipogeo_table_id_ipogeo_seq OWNED BY public.ipogeo_table.id_ipogeo;


--
-- TOC entry 317 (class 1259 OID 32663)
-- Name: layer_styles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.layer_styles (
    id integer NOT NULL,
    f_table_catalog character varying(256),
    f_table_schema character varying(256),
    f_table_name character varying(256),
    f_geometry_column character varying(256),
    stylename character varying(30),
    styleqml xml,
    stylesld xml,
    useasdefault boolean,
    description text,
    owner character varying(30),
    ui xml,
    update_time timestamp without time zone DEFAULT now()
);


ALTER TABLE public.layer_styles OWNER TO postgres;

--
-- TOC entry 318 (class 1259 OID 32670)
-- Name: layer_styles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.layer_styles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.layer_styles_id_seq OWNER TO postgres;

--
-- TOC entry 5045 (class 0 OID 0)
-- Dependencies: 318
-- Name: layer_styles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.layer_styles_id_seq OWNED BY public.layer_styles.id;


--
-- TOC entry 319 (class 1259 OID 32672)
-- Name: media_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.media_table (
    id_media integer NOT NULL,
    mediatype text,
    filename text,
    filetype character varying(10),
    filepath text,
    descrizione text,
    tags text
);


ALTER TABLE public.media_table OWNER TO postgres;

--
-- TOC entry 320 (class 1259 OID 32678)
-- Name: media_table_id_media_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.media_table_id_media_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.media_table_id_media_seq OWNER TO postgres;

--
-- TOC entry 5046 (class 0 OID 0)
-- Dependencies: 320
-- Name: media_table_id_media_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.media_table_id_media_seq OWNED BY public.media_table.id_media;


--
-- TOC entry 321 (class 1259 OID 32680)
-- Name: media_thumb_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.media_thumb_table (
    id_media_thumb integer NOT NULL,
    id_media integer,
    mediatype text,
    media_filename text,
    media_thumb_filename text,
    filetype character varying(10),
    filepath text
);


ALTER TABLE public.media_thumb_table OWNER TO postgres;

--
-- TOC entry 322 (class 1259 OID 32686)
-- Name: media_thumb_table_id_media_thumb_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.media_thumb_table_id_media_thumb_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.media_thumb_table_id_media_thumb_seq OWNER TO postgres;

--
-- TOC entry 5047 (class 0 OID 0)
-- Dependencies: 322
-- Name: media_thumb_table_id_media_thumb_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.media_thumb_table_id_media_thumb_seq OWNED BY public.media_thumb_table.id_media_thumb;


--
-- TOC entry 323 (class 1259 OID 32688)
-- Name: media_to_entity_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.media_to_entity_table (
    "id_mediaToEntity" integer NOT NULL,
    id_entity integer,
    entity_type text,
    table_name text,
    id_media integer,
    filepath text,
    media_name text
);


ALTER TABLE public.media_to_entity_table OWNER TO postgres;

--
-- TOC entry 324 (class 1259 OID 32694)
-- Name: media_to_entity_table_id_mediaToEntity_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."media_to_entity_table_id_mediaToEntity_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."media_to_entity_table_id_mediaToEntity_seq" OWNER TO postgres;

--
-- TOC entry 5048 (class 0 OID 0)
-- Dependencies: 324
-- Name: media_to_entity_table_id_mediaToEntity_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."media_to_entity_table_id_mediaToEntity_seq" OWNED BY public.media_to_entity_table."id_mediaToEntity";


--
-- TOC entry 325 (class 1259 OID 32696)
-- Name: media_to_us_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.media_to_us_table (
    "id_mediaToUs" integer NOT NULL,
    id_us integer,
    sito text,
    area character varying(4),
    us integer,
    id_media integer,
    filepath text
);


ALTER TABLE public.media_to_us_table OWNER TO postgres;

--
-- TOC entry 326 (class 1259 OID 32702)
-- Name: media_to_us_table_id_mediaToUs_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."media_to_us_table_id_mediaToUs_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."media_to_us_table_id_mediaToUs_seq" OWNER TO postgres;

--
-- TOC entry 5049 (class 0 OID 0)
-- Dependencies: 326
-- Name: media_to_us_table_id_mediaToUs_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."media_to_us_table_id_mediaToUs_seq" OWNED BY public.media_to_us_table."id_mediaToUs";


--
-- TOC entry 454 (class 1259 OID 181326)
-- Name: nove_rocche; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nove_rocche (
    gid integer NOT NULL,
    the_geom public.geometry(MultiPoint,25832),
    sito character varying(80),
    definizione character varying(20),
    quota_slm double precision,
    prima_attestazione bigint,
    tipo_localizzazione character varying(20),
    conservazione character varying(250),
    accessibil character varying(250),
    materiali character varying,
    note_biblio character varying,
    ultima_attestazione character varying,
    note character varying,
    rocca_number integer,
    "check" character varying,
    weblink character varying,
    convex_hull character(2),
    data_conv timestamp without time zone,
    anno_arch text,
    anno_arch_end text,
    sequenza_possessori text,
    itinerario text
);


ALTER TABLE public.nove_rocche OWNER TO postgres;

--
-- TOC entry 327 (class 1259 OID 32704)
-- Name: pdf_administrator_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pdf_administrator_table (
    id_pdf_administrator integer NOT NULL,
    table_name text,
    schema_griglia text,
    schema_fusione_celle text,
    modello text
);


ALTER TABLE public.pdf_administrator_table OWNER TO postgres;

--
-- TOC entry 328 (class 1259 OID 32710)
-- Name: pdf_administrator_table_id_pdf_administrator_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pdf_administrator_table_id_pdf_administrator_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pdf_administrator_table_id_pdf_administrator_seq OWNER TO postgres;

--
-- TOC entry 5050 (class 0 OID 0)
-- Dependencies: 328
-- Name: pdf_administrator_table_id_pdf_administrator_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pdf_administrator_table_id_pdf_administrator_seq OWNED BY public.pdf_administrator_table.id_pdf_administrator;


--
-- TOC entry 429 (class 1259 OID 82781)
-- Name: percorsi_visita; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.percorsi_visita (
    id bigint NOT NULL,
    geom public.geometry(MultiLineString,3004),
    sito character varying(254),
    definizion character varying(254),
    descrizion character varying(254),
    lungh double precision
);


ALTER TABLE public.percorsi_visita OWNER TO postgres;

--
-- TOC entry 329 (class 1259 OID 32712)
-- Name: periodizzazione_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.periodizzazione_table (
    id_perfas integer NOT NULL,
    sito text,
    periodo integer,
    fase integer,
    cron_iniziale integer,
    cron_finale integer,
    descrizione text,
    datazione_estesa character varying(300),
    cont_per integer
);


ALTER TABLE public.periodizzazione_table OWNER TO postgres;

--
-- TOC entry 330 (class 1259 OID 32718)
-- Name: periodizzazione_table_id_perfas_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.periodizzazione_table_id_perfas_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.periodizzazione_table_id_perfas_seq OWNER TO postgres;

--
-- TOC entry 5051 (class 0 OID 0)
-- Dependencies: 330
-- Name: periodizzazione_table_id_perfas_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.periodizzazione_table_id_perfas_seq OWNED BY public.periodizzazione_table.id_perfas;


--
-- TOC entry 331 (class 1259 OID 32720)
-- Name: pesaro_centrostorico_ctr_5000; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pesaro_centrostorico_ctr_5000 (
    gid integer NOT NULL,
    the_geom public.geometry(MultiLineString,3004),
    fid double precision
);


ALTER TABLE public.pesaro_centrostorico_ctr_5000 OWNER TO postgres;

--
-- TOC entry 332 (class 1259 OID 32726)
-- Name: pesaro_centrostorico_ctr_5000_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pesaro_centrostorico_ctr_5000_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pesaro_centrostorico_ctr_5000_gid_seq OWNER TO postgres;

--
-- TOC entry 5052 (class 0 OID 0)
-- Dependencies: 332
-- Name: pesaro_centrostorico_ctr_5000_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pesaro_centrostorico_ctr_5000_gid_seq OWNED BY public.pesaro_centrostorico_ctr_5000.gid;


--
-- TOC entry 333 (class 1259 OID 32728)
-- Name: pyarchinit_campionature; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_campionature (
    gid integer NOT NULL,
    id_campion integer,
    sito character varying(200),
    tipo_campi character varying(200),
    datazione_ character varying(200),
    cronologia integer,
    link_immag character varying(500),
    sigla_camp character varying,
    the_geom public.geometry(Point,3004)
);


ALTER TABLE public.pyarchinit_campionature OWNER TO postgres;

--
-- TOC entry 334 (class 1259 OID 32734)
-- Name: pyarchinit_codici_tipologia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_codici_tipologia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_codici_tipologia_id_seq OWNER TO postgres;

--
-- TOC entry 335 (class 1259 OID 32736)
-- Name: pyarchinit_codici_tipologia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_codici_tipologia (
    id integer DEFAULT nextval('public.pyarchinit_codici_tipologia_id_seq'::regclass) NOT NULL,
    tipologia_progetto character varying,
    tipologia_definizione_tipologia character varying,
    tipologia_gruppo character varying,
    tipologia_definizione_gruppo character varying,
    tipologia_codice character(5),
    tipologia_sottocodice character varying,
    tipologia_definizione_codice character varying,
    tipologia_descrizione character varying
);


ALTER TABLE public.pyarchinit_codici_tipologia OWNER TO postgres;

--
-- TOC entry 336 (class 1259 OID 32743)
-- Name: pyarchinit_individui; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_individui (
    gid integer NOT NULL,
    sito character varying(255),
    sigla_struttura character varying(255),
    note character varying(255),
    the_geom public.geometry(Point,3004),
    id_individuo integer
);


ALTER TABLE public.pyarchinit_individui OWNER TO postgres;

--
-- TOC entry 337 (class 1259 OID 32749)
-- Name: pyarchinit_individui_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_individui_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_individui_gid_seq OWNER TO postgres;

--
-- TOC entry 5053 (class 0 OID 0)
-- Dependencies: 337
-- Name: pyarchinit_individui_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pyarchinit_individui_gid_seq OWNED BY public.pyarchinit_individui.gid;


--
-- TOC entry 338 (class 1259 OID 32751)
-- Name: pyarchinit_individui_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_individui_view AS
 SELECT pyarchinit_individui.gid,
    pyarchinit_individui.the_geom,
    pyarchinit_individui.sito AS scavo,
    pyarchinit_individui.id_individuo,
    pyarchinit_individui.note,
    individui_table.id_scheda_ind,
    individui_table.sito,
    individui_table.area,
    individui_table.us,
    individui_table.nr_individuo,
    individui_table.data_schedatura,
    individui_table.schedatore,
    individui_table.sesso,
    individui_table.eta_min,
    individui_table.eta_max,
    individui_table.classi_eta,
    individui_table.osservazioni
   FROM (public.pyarchinit_individui
     JOIN public.individui_table ON ((((pyarchinit_individui.sito)::text = individui_table.sito) AND ((pyarchinit_individui.id_individuo)::text = (individui_table.nr_individuo)::text))));


ALTER TABLE public.pyarchinit_individui_view OWNER TO postgres;

--
-- TOC entry 339 (class 1259 OID 32756)
-- Name: pyarchinit_inventario_materiali; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_inventario_materiali (
    idim_pk integer NOT NULL,
    sito character varying(150),
    area integer,
    us integer,
    nr_cassa integer,
    tipo_materiale character varying(120) DEFAULT 'Ceramica'::character varying,
    nr_reperto integer,
    lavato_si_no character(2) DEFAULT 'si'::bpchar,
    descrizione_rep character varying
);


ALTER TABLE public.pyarchinit_inventario_materiali OWNER TO postgres;

SET default_with_oids = true;

--
-- TOC entry 340 (class 1259 OID 32764)
-- Name: pyarchinit_ipogei; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_ipogei (
    gid integer NOT NULL,
    sito_ipogeo_i character varying(80),
    nr_ipogeo_i integer,
    the_geom public.geometry,
    img_path character varying,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.pyarchinit_ipogei OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 32773)
-- Name: pyarchinit_ipogei_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_ipogei_view AS
 SELECT pyarchinit_ipogei.gid,
    pyarchinit_ipogei.sito_ipogeo_i,
    pyarchinit_ipogei.nr_ipogeo_i,
    pyarchinit_ipogei.the_geom,
    ipogeo_table.id_ipogeo,
    ipogeo_table.sito_ipogeo,
    ipogeo_table.sigla_ipogeo,
    ipogeo_table.numero_ipogeo,
    ipogeo_table.categoria_ipogeo,
    ipogeo_table.tipologia_ipogeo,
    ipogeo_table.definizione_ipogeo,
    ipogeo_table.descrizione_ipogeo,
    ipogeo_table.interpretazione_ipogeo,
    ipogeo_table.periodo_iniziale_ipogeo,
    ipogeo_table.fase_iniziale_ipogeo,
    ipogeo_table.periodo_finale_ipogeo,
    ipogeo_table.fase_finale_ipogeo,
    ipogeo_table.datazione_estesa_ipogeo,
    ipogeo_table.materiali_impiegati_ipogeo,
    ipogeo_table.elementi_strutturali_ipogeo,
    ipogeo_table.rapporti_ipogeo,
    ipogeo_table.misure_ipogeo,
    ipogeo_table.percentuale_umidita_ipogeo,
    ipogeo_table.grado_conservazione_ipogeo,
    ipogeo_table.grado_staticita_ipogeo
   FROM (public.pyarchinit_ipogei
     JOIN public.ipogeo_table ON ((((pyarchinit_ipogei.sito_ipogeo_i)::text = ipogeo_table.sito_ipogeo) AND ((pyarchinit_ipogei.nr_ipogeo_i)::text = (ipogeo_table.numero_ipogeo)::text))));


ALTER TABLE public.pyarchinit_ipogei_view OWNER TO postgres;

--
-- TOC entry 342 (class 1259 OID 32778)
-- Name: pyarchinit_linee_rif_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_linee_rif_gid_seq
    START WITH 6375
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_linee_rif_gid_seq OWNER TO postgres;

SET default_with_oids = false;

--
-- TOC entry 343 (class 1259 OID 32780)
-- Name: pyarchinit_linee_rif; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_linee_rif (
    gid integer DEFAULT nextval('public.pyarchinit_linee_rif_gid_seq'::regclass) NOT NULL,
    sito character varying(300),
    definizion character varying(80),
    descrizion character varying(80),
    the_geom public.geometry(LineString,3004),
    distanza numeric(10,2)
);


ALTER TABLE public.pyarchinit_linee_rif OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 32787)
-- Name: pyarchinit_punti_rif_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_punti_rif_gid_seq
    START WITH 4928
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_punti_rif_gid_seq OWNER TO postgres;

--
-- TOC entry 345 (class 1259 OID 32789)
-- Name: pyarchinit_punti_rif; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_punti_rif (
    gid integer DEFAULT nextval('public.pyarchinit_punti_rif_gid_seq'::regclass) NOT NULL,
    sito character varying(80),
    def_punto character varying(80),
    id_punto character varying(80),
    quota double precision,
    the_geom public.geometry(Point,3004),
    unita_misura_quota character varying,
    area integer,
    orientamento numeric(5,2)
);


ALTER TABLE public.pyarchinit_punti_rif OWNER TO postgres;

--
-- TOC entry 346 (class 1259 OID 32796)
-- Name: pyuscarlinee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyuscarlinee (
    gid integer NOT NULL,
    sito_l character varying(150),
    area_l integer,
    us_l integer,
    tipo_us_l character varying(150),
    the_geom public.geometry(LineString,3004)
);


ALTER TABLE public.pyuscarlinee OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 32802)
-- Name: us_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.us_table (
    id_us integer NOT NULL,
    sito text,
    area character varying(4),
    us integer,
    d_stratigrafica character varying(100),
    d_interpretativa character varying(100),
    descrizione text,
    interpretazione text,
    periodo_iniziale character varying(4),
    fase_iniziale character varying(4),
    periodo_finale character varying(4),
    fase_finale character varying(4),
    scavato character varying(2),
    attivita character varying(4),
    anno_scavo character varying(4),
    metodo_di_scavo character varying(20),
    inclusi text,
    campioni text,
    rapporti text,
    data_schedatura character varying(20),
    schedatore character varying(25),
    formazione character varying(20),
    stato_di_conservazione character varying(20),
    colore character varying(20),
    consistenza character varying(20),
    struttura character varying(30),
    cont_per character varying(200),
    order_layer integer DEFAULT 0,
    documentazione text,
    unita_tipo character varying DEFAULT 'US'::character varying,
    settore text DEFAULT ''::text,
    quad_par text DEFAULT ''::text,
    ambient text DEFAULT ''::text,
    saggio text DEFAULT ''::text,
    elem_datanti text DEFAULT ''::text,
    funz_statica text DEFAULT ''::text,
    lavorazione text DEFAULT ''::text,
    spess_giunti text DEFAULT ''::text,
    letti_posa text DEFAULT ''::text,
    alt_mod text DEFAULT ''::text,
    un_ed_riass text DEFAULT ''::text,
    reimp text DEFAULT ''::text,
    posa_opera text DEFAULT ''::text,
    quota_min_usm numeric(6,2),
    quota_max_usm numeric(6,2),
    cons_legante text DEFAULT ''::text,
    col_legante text DEFAULT ''::text,
    aggreg_legante text DEFAULT ''::text,
    con_text_mat text DEFAULT ''::text,
    col_materiale text DEFAULT ''::text,
    inclusi_materiali_usm text DEFAULT '[]'::text,
    n_catalogo_generale text DEFAULT ''::text,
    n_catalogo_interno text DEFAULT ''::text,
    n_catalogo_internazionale text DEFAULT ''::text,
    soprintendenza text DEFAULT ''::text,
    quota_relativa numeric(6,2),
    quota_abs numeric(6,2),
    ref_tm text DEFAULT ''::text,
    ref_ra text DEFAULT ''::text,
    ref_n text DEFAULT ''::text,
    posizione text DEFAULT ''::text,
    criteri_distinzione text DEFAULT ''::text,
    modo_formazione text DEFAULT ''::text,
    componenti_organici text DEFAULT ''::text,
    componenti_inorganici text DEFAULT ''::text,
    lunghezza_max numeric(6,2),
    altezza_max numeric(6,2),
    altezza_min numeric(6,2),
    profondita_max numeric(6,2),
    profondita_min numeric(6,2),
    larghezza_media numeric(6,2),
    quota_max_abs numeric(6,2),
    quota_max_rel numeric(6,2),
    quota_min_abs numeric(6,2),
    quota_min_rel numeric(6,2),
    osservazioni text DEFAULT ''::text,
    datazione text DEFAULT ''::text,
    flottazione text DEFAULT ''::text,
    setacciatura text DEFAULT ''::text,
    affidabilita text DEFAULT ''::text,
    direttore_us text DEFAULT ''::text,
    responsabile_us text DEFAULT ''::text,
    cod_ente_schedatore text DEFAULT ''::text,
    data_rilevazione text DEFAULT ''::text,
    data_rielaborazione text DEFAULT ''::text,
    lunghezza_usm numeric(6,2),
    altezza_usm numeric(6,2),
    spessore_usm numeric(6,2),
    tecnica_muraria_usm text DEFAULT ''::text,
    modulo_usm text DEFAULT ''::text,
    campioni_malta_usm text DEFAULT ''::text,
    campioni_mattone_usm text DEFAULT ''::text,
    campioni_pietra_usm text DEFAULT ''::text,
    provenienza_materiali_usm text DEFAULT ''::text,
    criteri_distinzione_usm text DEFAULT ''::text,
    uso_primario_usm text DEFAULT ''::text
);


ALTER TABLE public.us_table OWNER TO postgres;

--
-- TOC entry 348 (class 1259 OID 32809)
-- Name: pyarchinit_pyuscarlinee_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_pyuscarlinee_view AS
 SELECT pyuscarlinee.gid,
    pyuscarlinee.the_geom,
    pyuscarlinee.tipo_us_l,
    pyuscarlinee.sito_l,
    pyuscarlinee.area_l,
    pyuscarlinee.us_l,
    us_table.sito,
    us_table.id_us,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per
   FROM (public.pyuscarlinee
     JOIN public.us_table ON (((((pyuscarlinee.sito_l)::text = us_table.sito) AND ((pyuscarlinee.area_l)::text = (us_table.area)::text)) AND (pyuscarlinee.us_l = us_table.us))));


ALTER TABLE public.pyarchinit_pyuscarlinee_view OWNER TO postgres;

--
-- TOC entry 349 (class 1259 OID 32814)
-- Name: pyarchinit_quote_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_quote_gid_seq
    START WITH 73833
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_quote_gid_seq OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 32816)
-- Name: pyarchinit_quote; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_quote (
    gid integer DEFAULT nextval('public.pyarchinit_quote_gid_seq'::regclass) NOT NULL,
    sito_q character varying(80),
    area_q integer,
    us_q integer,
    unita_misu_q character varying(80),
    quota_q double precision,
    the_geom public.geometry(Point,3004),
    data character varying,
    disegnatore character varying,
    rilievo_originale character varying
);


ALTER TABLE public.pyarchinit_quote OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 32823)
-- Name: pyarchinit_quote_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_quote_view AS
 SELECT pyarchinit_quote.gid,
    pyarchinit_quote.sito_q,
    pyarchinit_quote.area_q,
    pyarchinit_quote.us_q,
    pyarchinit_quote.unita_misu_q,
    pyarchinit_quote.quota_q,
    pyarchinit_quote.the_geom,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica,
    us_table.d_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per
   FROM (public.pyarchinit_quote
     JOIN public.us_table ON (((((pyarchinit_quote.sito_q)::text = us_table.sito) AND ((pyarchinit_quote.area_q)::text = (us_table.area)::text)) AND ((pyarchinit_quote.us_q)::text = (us_table.us)::text))));


ALTER TABLE public.pyarchinit_quote_view OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 32828)
-- Name: pyarchinit_ripartizioni_spaziali_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_ripartizioni_spaziali_gid_seq
    START WITH 2007
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_ripartizioni_spaziali_gid_seq OWNER TO postgres;

--
-- TOC entry 353 (class 1259 OID 32830)
-- Name: pyarchinit_ripartizioni_spaziali; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_ripartizioni_spaziali (
    gid integer DEFAULT nextval('public.pyarchinit_ripartizioni_spaziali_gid_seq'::regclass) NOT NULL,
    id_rs character varying(80),
    sito_rs character varying(80),
    the_geom public.geometry(Polygon,3004),
    tip_rip character varying,
    descr_rs character varying
);


ALTER TABLE public.pyarchinit_ripartizioni_spaziali OWNER TO postgres;

--
-- TOC entry 354 (class 1259 OID 32837)
-- Name: pyarchinit_ripartizioni_temporali; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_ripartizioni_temporali (
    sito character varying,
    sigla_periodo character varying(10),
    sigla_fase character varying(10),
    cronologia_numerica integer,
    cronologia_numerica_finale integer,
    datazione_estesa_stringa character varying,
    id_periodo integer NOT NULL,
    descrizione character varying
);


ALTER TABLE public.pyarchinit_ripartizioni_temporali OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 32843)
-- Name: pyarchinit_ripartizioni_temporali_id_periodo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_ripartizioni_temporali_id_periodo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_ripartizioni_temporali_id_periodo_seq OWNER TO postgres;

--
-- TOC entry 5054 (class 0 OID 0)
-- Dependencies: 355
-- Name: pyarchinit_ripartizioni_temporali_id_periodo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pyarchinit_ripartizioni_temporali_id_periodo_seq OWNED BY public.pyarchinit_ripartizioni_temporali.id_periodo;


--
-- TOC entry 356 (class 1259 OID 32845)
-- Name: pyarchinit_rou_thesaurus; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_rou_thesaurus (
    "ID_rou" integer NOT NULL,
    valore_ro character varying,
    rou_descrizione character varying
);


ALTER TABLE public.pyarchinit_rou_thesaurus OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 32851)
-- Name: pyarchinit_rou_thesaurus_ID_rou_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."pyarchinit_rou_thesaurus_ID_rou_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."pyarchinit_rou_thesaurus_ID_rou_seq" OWNER TO postgres;

--
-- TOC entry 5055 (class 0 OID 0)
-- Dependencies: 357
-- Name: pyarchinit_rou_thesaurus_ID_rou_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."pyarchinit_rou_thesaurus_ID_rou_seq" OWNED BY public.pyarchinit_rou_thesaurus."ID_rou";


--
-- TOC entry 358 (class 1259 OID 32853)
-- Name: pyarchinit_sezioni_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_sezioni_gid_seq
    START WITH 1223
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_sezioni_gid_seq OWNER TO postgres;

--
-- TOC entry 359 (class 1259 OID 32855)
-- Name: pyarchinit_sezioni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_sezioni (
    gid integer DEFAULT nextval('public.pyarchinit_sezioni_gid_seq'::regclass) NOT NULL,
    id_sezione character varying(80),
    sito character varying(80),
    area integer,
    descr character varying(80),
    the_geom public.geometry(LineString,3004)
);


ALTER TABLE public.pyarchinit_sezioni OWNER TO postgres;

--
-- TOC entry 360 (class 1259 OID 32862)
-- Name: pyarchinit_siti_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_siti_gid_seq
    START WITH 112
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_siti_gid_seq OWNER TO postgres;

--
-- TOC entry 361 (class 1259 OID 32864)
-- Name: pyarchinit_siti; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_siti (
    gid integer DEFAULT nextval('public.pyarchinit_siti_gid_seq'::regclass) NOT NULL,
    sito_nome character varying(80),
    the_geom public.geometry(Point,3004),
    link character varying(300)
);


ALTER TABLE public.pyarchinit_siti OWNER TO postgres;

--
-- TOC entry 362 (class 1259 OID 32871)
-- Name: pyarchinit_sondaggi_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_sondaggi_gid_seq
    START WITH 1262
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_sondaggi_gid_seq OWNER TO postgres;

--
-- TOC entry 363 (class 1259 OID 32873)
-- Name: pyarchinit_sondaggi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_sondaggi (
    gid integer DEFAULT nextval('public.pyarchinit_sondaggi_gid_seq'::regclass) NOT NULL,
    sito character varying(80),
    id_sondagg character varying(80),
    the_geom public.geometry(Polygon,3004)
);


ALTER TABLE public.pyarchinit_sondaggi OWNER TO postgres;

--
-- TOC entry 364 (class 1259 OID 32880)
-- Name: pyarchinit_strutture_ipotesi_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_strutture_ipotesi_gid_seq
    START WITH 842
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_strutture_ipotesi_gid_seq OWNER TO postgres;

--
-- TOC entry 365 (class 1259 OID 32882)
-- Name: pyarchinit_strutture_ipotesi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_strutture_ipotesi (
    gid integer DEFAULT nextval('public.pyarchinit_strutture_ipotesi_gid_seq'::regclass) NOT NULL,
    sito character varying(80),
    id_strutt character varying(80),
    per_iniz integer,
    per_fin integer,
    dataz_ext character varying(80),
    the_geom public.geometry(Polygon,3004),
    fase_iniz integer,
    fase_fin integer,
    descrizione character varying,
    nr_strut integer DEFAULT 0,
    sigla_strut character varying(3) DEFAULT 'NoD'::character varying
);


ALTER TABLE public.pyarchinit_strutture_ipotesi OWNER TO postgres;

--
-- TOC entry 400 (class 1259 OID 33070)
-- Name: struttura_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.struttura_table (
    id_struttura integer NOT NULL,
    sito text,
    sigla_struttura text,
    numero_struttura integer,
    categoria_struttura text,
    tipologia_struttura text,
    definizione_struttura text,
    descrizione text,
    interpretazione text,
    periodo_iniziale integer,
    fase_iniziale integer,
    periodo_finale integer,
    fase_finale integer,
    datazione_estesa character varying(300),
    materiali_impiegati text,
    elementi_strutturali text,
    rapporti_struttura text,
    misure_struttura text
);


ALTER TABLE public.struttura_table OWNER TO postgres;

--
-- TOC entry 420 (class 1259 OID 58122)
-- Name: pyarchinit_strutture_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_strutture_view AS
 SELECT a.gid,
    a.sito,
    a.id_strutt,
    a.per_iniz,
    a.per_fin,
    a.dataz_ext,
    a.fase_iniz,
    a.fase_fin,
    a.descrizione,
    a.the_geom,
    a.sigla_strut,
    a.nr_strut,
    b.id_struttura,
    b.sito AS sito_1,
    b.sigla_struttura,
    b.numero_struttura,
    b.categoria_struttura,
    b.tipologia_struttura,
    b.definizione_struttura,
    b.descrizione AS descrizione_1,
    b.interpretazione,
    b.periodo_iniziale,
    b.fase_iniziale,
    b.periodo_finale,
    b.fase_finale,
    b.datazione_estesa,
    b.materiali_impiegati,
    b.elementi_strutturali,
    b.rapporti_struttura,
    b.misure_struttura
   FROM (public.pyarchinit_strutture_ipotesi a
     JOIN public.struttura_table b ON (((((a.sito)::text = b.sito) AND ((a.sigla_strut)::text = b.sigla_struttura)) AND (a.nr_strut = b.numero_struttura))));


ALTER TABLE public.pyarchinit_strutture_view OWNER TO postgres;

--
-- TOC entry 366 (class 1259 OID 32891)
-- Name: pyarchinit_tafonomia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_tafonomia (
    gid integer NOT NULL,
    the_geom public.geometry(Point,3004),
    id_tafonomia_pk bigint,
    sito character varying,
    nr_scheda bigint
);


ALTER TABLE public.pyarchinit_tafonomia OWNER TO postgres;

--
-- TOC entry 367 (class 1259 OID 32897)
-- Name: pyarchinit_tafonomia_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_tafonomia_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_tafonomia_gid_seq OWNER TO postgres;

--
-- TOC entry 5056 (class 0 OID 0)
-- Dependencies: 367
-- Name: pyarchinit_tafonomia_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pyarchinit_tafonomia_gid_seq OWNED BY public.pyarchinit_tafonomia.gid;


--
-- TOC entry 368 (class 1259 OID 32899)
-- Name: tafonomia_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tafonomia_table (
    id_tafonomia integer NOT NULL,
    sito text,
    nr_scheda_taf integer,
    sigla_struttura text,
    nr_struttura integer,
    nr_individuo integer,
    rito text,
    descrizione_taf text,
    interpretazione_taf text,
    segnacoli text,
    canale_libatorio_si_no text,
    oggetti_rinvenuti_esterno text,
    stato_di_conservazione text,
    copertura_tipo text,
    tipo_contenitore_resti text,
    orientamento_asse text,
    orientamento_azimut real,
    riferimenti_stratigrafici text,
    corredo_presenza text,
    corredo_tipo text,
    corredo_descrizione text,
    lunghezza_scheletro real,
    posizione_scheletro character varying(150),
    posizione_cranio character varying(150),
    posizione_arti_superiori character varying(150),
    posizione_arti_inferiori character varying(150),
    completo_si_no character varying(2),
    disturbato_si_no character varying(2),
    in_connessione_si_no character varying(2),
    caratteristiche text,
    periodo_iniziale integer,
    fase_iniziale integer,
    periodo_finale integer,
    fase_finale integer,
    datazione_estesa text,
    misure_tafonomia text DEFAULT '[]'::text
);


ALTER TABLE public.tafonomia_table OWNER TO postgres;

--
-- TOC entry 369 (class 1259 OID 32906)
-- Name: pyarchinit_tafonomia_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_tafonomia_view AS
 SELECT a.id_tafonomia,
    a.sito,
    a.nr_scheda_taf,
    a.sigla_struttura,
    a.nr_struttura,
    a.nr_individuo,
    a.rito,
    a.descrizione_taf,
    a.interpretazione_taf,
    a.segnacoli,
    a.canale_libatorio_si_no,
    a.oggetti_rinvenuti_esterno,
    a.stato_di_conservazione,
    a.copertura_tipo,
    a.tipo_contenitore_resti,
    a.orientamento_asse,
    a.orientamento_azimut,
    a.riferimenti_stratigrafici,
    a.corredo_presenza,
    a.corredo_tipo,
    a.corredo_descrizione,
    a.lunghezza_scheletro,
    a.posizione_scheletro,
    a.posizione_cranio,
    a.posizione_arti_superiori,
    a.posizione_arti_inferiori,
    a.completo_si_no,
    a.disturbato_si_no,
    a.in_connessione_si_no,
    a.caratteristiche,
    b.gid,
    b.id_tafonomia_pk,
    b.sito AS sito_1,
    b.nr_scheda,
    b.the_geom
   FROM (public.tafonomia_table a
     JOIN public.pyarchinit_tafonomia b ON (((a.sito = (b.sito)::text) AND (a.nr_scheda_taf = b.nr_scheda))));


ALTER TABLE public.pyarchinit_tafonomia_view OWNER TO postgres;

--
-- TOC entry 370 (class 1259 OID 32911)
-- Name: pyarchinit_thesaurus_sigle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_thesaurus_sigle (
    id_thesaurus_sigle integer NOT NULL,
    nome_tabella character varying,
    sigla character(3),
    sigla_estesa character varying,
    descrizione character varying,
    tipologia_sigla character varying
);


ALTER TABLE public.pyarchinit_thesaurus_sigle OWNER TO postgres;

--
-- TOC entry 371 (class 1259 OID 32917)
-- Name: pyarchinit_thesaurus_sigle_id_thesaurus_sigle_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_thesaurus_sigle_id_thesaurus_sigle_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_thesaurus_sigle_id_thesaurus_sigle_seq OWNER TO postgres;

--
-- TOC entry 5057 (class 0 OID 0)
-- Dependencies: 371
-- Name: pyarchinit_thesaurus_sigle_id_thesaurus_sigle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pyarchinit_thesaurus_sigle_id_thesaurus_sigle_seq OWNED BY public.pyarchinit_thesaurus_sigle.id_thesaurus_sigle;


--
-- TOC entry 372 (class 1259 OID 32919)
-- Name: pyarchinit_tipologia_sepolture_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_tipologia_sepolture_gid_seq
    START WITH 452
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_tipologia_sepolture_gid_seq OWNER TO postgres;

--
-- TOC entry 373 (class 1259 OID 32921)
-- Name: pyarchinit_tipologia_sepolture; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_tipologia_sepolture (
    gid integer DEFAULT nextval('public.pyarchinit_tipologia_sepolture_gid_seq'::regclass) NOT NULL,
    id_sepoltura character varying(80),
    azimut double precision,
    tipologia character varying(80),
    the_geom public.geometry(Point,3004),
    sito_ts character varying,
    t_progetto character varying,
    t_gruppo character varying,
    t_codice character varying,
    t_sottocodice character varying,
    corredo character varying
);


ALTER TABLE public.pyarchinit_tipologia_sepolture OWNER TO postgres;

--
-- TOC entry 374 (class 1259 OID 32928)
-- Name: pyarchinit_tipologie_sepolture_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_tipologie_sepolture_view AS
 SELECT pyarchinit_quote_view.gid,
    pyarchinit_quote_view.sito_q,
    pyarchinit_quote_view.area_q,
    pyarchinit_quote_view.us_q,
    pyarchinit_quote_view.unita_misu_q,
    pyarchinit_quote_view.quota_q,
    pyarchinit_quote_view.id_us,
    pyarchinit_quote_view.sito,
    pyarchinit_quote_view.area,
    pyarchinit_quote_view.us,
    pyarchinit_quote_view.struttura,
    pyarchinit_quote_view.d_stratigrafica,
    pyarchinit_quote_view.d_interpretativa,
    pyarchinit_quote_view.descrizione,
    pyarchinit_quote_view.interpretazione,
    pyarchinit_quote_view.rapporti,
    pyarchinit_quote_view.periodo_iniziale,
    pyarchinit_quote_view.fase_iniziale,
    pyarchinit_quote_view.periodo_finale,
    pyarchinit_quote_view.fase_finale,
    pyarchinit_quote_view.anno_scavo,
    pyarchinit_tipologia_sepolture.id_sepoltura,
    pyarchinit_tipologia_sepolture.azimut,
    pyarchinit_tipologia_sepolture.tipologia,
    pyarchinit_tipologia_sepolture.the_geom,
    pyarchinit_tipologia_sepolture.sito_ts,
    pyarchinit_tipologia_sepolture.t_progetto AS tipologia_progetto,
    pyarchinit_tipologia_sepolture.t_gruppo AS tipologia_gruppo,
    pyarchinit_tipologia_sepolture.t_codice AS tipologia_codice,
    pyarchinit_tipologia_sepolture.t_sottocodice AS tipologia_sottocodice
   FROM (public.pyarchinit_quote_view
     JOIN public.pyarchinit_tipologia_sepolture ON (((pyarchinit_quote_view.struttura)::text = (pyarchinit_tipologia_sepolture.id_sepoltura)::text)));


ALTER TABLE public.pyarchinit_tipologie_sepolture_view OWNER TO postgres;

--
-- TOC entry 375 (class 1259 OID 32933)
-- Name: pyarchinit_tipologie_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_tipologie_view AS
 SELECT pyarchinit_tipologia_sepolture.gid,
    pyarchinit_tipologia_sepolture.id_sepoltura,
    pyarchinit_tipologia_sepolture.azimut,
    pyarchinit_tipologia_sepolture.the_geom,
    pyarchinit_tipologia_sepolture.sito_ts,
    pyarchinit_tipologia_sepolture.t_progetto,
    pyarchinit_tipologia_sepolture.t_gruppo,
    pyarchinit_tipologia_sepolture.t_codice,
    pyarchinit_tipologia_sepolture.t_sottocodice,
    pyarchinit_tipologia_sepolture.corredo,
    pyarchinit_codici_tipologia.tipologia_progetto,
    pyarchinit_codici_tipologia.tipologia_definizione_tipologia,
    pyarchinit_codici_tipologia.tipologia_gruppo,
    pyarchinit_codici_tipologia.tipologia_definizione_gruppo,
    pyarchinit_codici_tipologia.tipologia_codice,
    pyarchinit_codici_tipologia.tipologia_sottocodice,
    pyarchinit_codici_tipologia.tipologia_definizione_codice,
    pyarchinit_codici_tipologia.tipologia_descrizione
   FROM (public.pyarchinit_tipologia_sepolture
     JOIN public.pyarchinit_codici_tipologia ON ((((((pyarchinit_tipologia_sepolture.t_progetto)::text = (pyarchinit_codici_tipologia.tipologia_progetto)::text) AND ((pyarchinit_tipologia_sepolture.t_gruppo)::text = (pyarchinit_codici_tipologia.tipologia_gruppo)::text)) AND ((pyarchinit_tipologia_sepolture.t_codice)::text = (pyarchinit_codici_tipologia.tipologia_codice)::text)) AND ((pyarchinit_tipologia_sepolture.t_sottocodice)::text = (pyarchinit_codici_tipologia.tipologia_sottocodice)::text))));


ALTER TABLE public.pyarchinit_tipologie_view OWNER TO postgres;

--
-- TOC entry 376 (class 1259 OID 32938)
-- Name: pyarchinit_us_negative_doc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyarchinit_us_negative_doc (
    id integer NOT NULL,
    geom public.geometry(LineString,3004),
    sito_n character varying,
    area_n character varying,
    us_n bigint,
    tipo_doc_n character varying,
    nome_doc_n character varying,
    "LblSize" integer,
    "LblColor" character varying(7),
    "LblBold" integer,
    "LblItalic" integer,
    "LblUnderl" integer,
    "LblStrike" integer,
    "LblFont" character varying(100),
    "LblX" numeric(20,5),
    "LblY" numeric(20,5),
    "LblSclMin" integer,
    "LblSclMax" integer,
    "LblAlignH" character varying(15),
    "LblAlignV" character varying(15),
    "LblRot" numeric(20,5)
);


ALTER TABLE public.pyarchinit_us_negative_doc OWNER TO postgres;

--
-- TOC entry 377 (class 1259 OID 32944)
-- Name: pyarchinit_us_negative_doc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyarchinit_us_negative_doc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyarchinit_us_negative_doc_id_seq OWNER TO postgres;

--
-- TOC entry 5058 (class 0 OID 0)
-- Dependencies: 377
-- Name: pyarchinit_us_negative_doc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pyarchinit_us_negative_doc_id_seq OWNED BY public.pyarchinit_us_negative_doc.id;


--
-- TOC entry 378 (class 1259 OID 32946)
-- Name: pyunitastratigrafiche_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyunitastratigrafiche_gid_seq
    START WITH 61400
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyunitastratigrafiche_gid_seq OWNER TO postgres;

--
-- TOC entry 379 (class 1259 OID 32948)
-- Name: pyunitastratigrafiche; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyunitastratigrafiche (
    gid integer DEFAULT nextval('public.pyunitastratigrafiche_gid_seq'::regclass) NOT NULL,
    area_s integer,
    scavo_s character varying(80),
    us_s integer,
    the_geom public.geometry(MultiPolygon,3004),
    stratigraph_index_us integer,
    tipo_us_s character varying,
    rilievo_orginale character varying,
    disegnatore character varying,
    data date,
    tipo_doc character varying(250),
    nome_doc character varying(250)
);


ALTER TABLE public.pyunitastratigrafiche OWNER TO postgres;

--
-- TOC entry 380 (class 1259 OID 32955)
-- Name: pyarchinit_us_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_us_view AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer,
    us_table.attivita
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer, pyunitastratigrafiche.stratigraph_index_us DESC, pyunitastratigrafiche.gid;


ALTER TABLE public.pyarchinit_us_view OWNER TO postgres;

--
-- TOC entry 455 (class 1259 OID 189537)
-- Name: pyarchinit_us_view_f; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_us_view_f AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    pyunitastratigrafiche.rilievo_orginale,
    pyunitastratigrafiche.disegnatore,
    pyunitastratigrafiche.data,
    pyunitastratigrafiche.tipo_doc,
    pyunitastratigrafiche.nome_doc,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer,
    us_table.attivita
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer, pyunitastratigrafiche.stratigraph_index_us DESC, pyunitastratigrafiche.gid;


ALTER TABLE public.pyarchinit_us_view_f OWNER TO postgres;

--
-- TOC entry 381 (class 1259 OID 32960)
-- Name: pyarchinit_us_view_xx_settembre; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_us_view_xx_settembre AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer,
    us_table.attivita
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer, pyunitastratigrafiche.stratigraph_index_us DESC, pyunitastratigrafiche.gid;


ALTER TABLE public.pyarchinit_us_view_xx_settembre OWNER TO postgres;

--
-- TOC entry 382 (class 1259 OID 32965)
-- Name: pyarchinit_usb_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_usb_view AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer DESC, pyunitastratigrafiche.stratigraph_index_us DESC;


ALTER TABLE public.pyarchinit_usb_view OWNER TO postgres;

--
-- TOC entry 383 (class 1259 OID 32970)
-- Name: pyarchinit_usc_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_usc_view AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer;


ALTER TABLE public.pyarchinit_usc_view OWNER TO postgres;

--
-- TOC entry 384 (class 1259 OID 32975)
-- Name: pyuscaratterizzazioni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pyuscaratterizzazioni (
    gid integer NOT NULL,
    area_c integer,
    scavo_c character varying(80),
    us_c integer,
    the_geom public.geometry(MultiPolygon,3004),
    stratigraph_index_car integer DEFAULT 1,
    tipo_us_c character varying
);


ALTER TABLE public.pyuscaratterizzazioni OWNER TO postgres;

--
-- TOC entry 385 (class 1259 OID 32982)
-- Name: pyarchinit_uscaratterizzazioni_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_uscaratterizzazioni_view AS
 SELECT pyuscaratterizzazioni.gid,
    pyuscaratterizzazioni.the_geom,
    pyuscaratterizzazioni.tipo_us_c,
    pyuscaratterizzazioni.scavo_c,
    pyuscaratterizzazioni.area_c,
    pyuscaratterizzazioni.us_c,
    us_table.sito,
    us_table.id_us,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per
   FROM (public.pyuscaratterizzazioni
     JOIN public.us_table ON (((((pyuscaratterizzazioni.scavo_c)::text = us_table.sito) AND ((pyuscaratterizzazioni.area_c)::text = (us_table.area)::text)) AND (pyuscaratterizzazioni.us_c = us_table.us))));


ALTER TABLE public.pyarchinit_uscaratterizzazioni_view OWNER TO postgres;

--
-- TOC entry 386 (class 1259 OID 32987)
-- Name: pyarchinit_usd_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_usd_view AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer DESC, pyunitastratigrafiche.stratigraph_index_us DESC, pyunitastratigrafiche.gid DESC;


ALTER TABLE public.pyarchinit_usd_view OWNER TO postgres;

--
-- TOC entry 451 (class 1259 OID 173121)
-- Name: pyarchinit_use_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pyarchinit_use_view AS
 SELECT pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom,
    pyunitastratigrafiche.tipo_us_s,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.stratigraph_index_us,
    us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    us_table.d_stratigrafica AS definizione_stratigrafica,
    us_table.d_interpretativa AS definizione_interpretativa,
    us_table.descrizione,
    us_table.interpretazione,
    us_table.rapporti,
    us_table.periodo_iniziale,
    us_table.fase_iniziale,
    us_table.periodo_finale,
    us_table.fase_finale,
    us_table.anno_scavo,
    us_table.cont_per,
    us_table.order_layer
   FROM (public.pyunitastratigrafiche
     JOIN public.us_table ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))))
  ORDER BY us_table.order_layer DESC, pyunitastratigrafiche.stratigraph_index_us DESC, pyunitastratigrafiche.gid DESC;


ALTER TABLE public.pyarchinit_use_view OWNER TO postgres;

--
-- TOC entry 387 (class 1259 OID 32992)
-- Name: pyuscarlinee_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pyuscarlinee_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pyuscarlinee_gid_seq OWNER TO postgres;

--
-- TOC entry 5059 (class 0 OID 0)
-- Dependencies: 387
-- Name: pyuscarlinee_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pyuscarlinee_gid_seq OWNED BY public.pyuscarlinee.gid;


--
-- TOC entry 417 (class 1259 OID 41273)
-- Name: relashionship_check_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relashionship_check_table (
    id_rel_check integer NOT NULL,
    sito text,
    area text,
    us integer,
    rel_type text,
    sito_rel text,
    area_rel text,
    us_rel text,
    error_type text,
    note text
);


ALTER TABLE public.relashionship_check_table OWNER TO postgres;

--
-- TOC entry 416 (class 1259 OID 41271)
-- Name: relashionship_check_table_id_rel_check_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.relashionship_check_table_id_rel_check_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.relashionship_check_table_id_rel_check_seq OWNER TO postgres;

--
-- TOC entry 5060 (class 0 OID 0)
-- Dependencies: 416
-- Name: relashionship_check_table_id_rel_check_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.relashionship_check_table_id_rel_check_seq OWNED BY public.relashionship_check_table.id_rel_check;


--
-- TOC entry 458 (class 1259 OID 230517)
-- Name: rif_biblio_siti_idbibliositi_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rif_biblio_siti_idbibliositi_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rif_biblio_siti_idbibliositi_pk_seq OWNER TO postgres;

--
-- TOC entry 459 (class 1259 OID 230519)
-- Name: rif_biblio_siti; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rif_biblio_siti (
    id_rif_biblio_siti_pk integer DEFAULT nextval('public.rif_biblio_siti_idbibliositi_pk_seq'::regclass) NOT NULL,
    id_sito character varying,
    id_biblio character varying,
    page character varying
);


ALTER TABLE public.rif_biblio_siti OWNER TO postgres;

--
-- TOC entry 422 (class 1259 OID 66359)
-- Name: riipartizione_territoriale; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.riipartizione_territoriale (
    id_div_terr_pk integer NOT NULL,
    tipo text NOT NULL,
    nome text NOT NULL,
    tipo_localizzazione text NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.riipartizione_territoriale OWNER TO postgres;

--
-- TOC entry 421 (class 1259 OID 66357)
-- Name: riipartizione_territoriale_id_div_terr_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.riipartizione_territoriale_id_div_terr_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.riipartizione_territoriale_id_div_terr_pk_seq OWNER TO postgres;

--
-- TOC entry 5061 (class 0 OID 0)
-- Dependencies: 421
-- Name: riipartizione_territoriale_id_div_terr_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.riipartizione_territoriale_id_div_terr_pk_seq OWNED BY public.riipartizione_territoriale.id_div_terr_pk;


--
-- TOC entry 424 (class 1259 OID 66371)
-- Name: riipartizione_territoriale_to_rip_terr; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.riipartizione_territoriale_to_rip_terr (
    id_rel_rip_ter_pk integer NOT NULL,
    id_rip_prim integer NOT NULL,
    id_rip_second integer NOT NULL
);


ALTER TABLE public.riipartizione_territoriale_to_rip_terr OWNER TO postgres;

--
-- TOC entry 423 (class 1259 OID 66369)
-- Name: riipartizione_territoriale_to_rip_terr_id_rel_rip_ter_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.riipartizione_territoriale_to_rip_terr_id_rel_rip_ter_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.riipartizione_territoriale_to_rip_terr_id_rel_rip_ter_pk_seq OWNER TO postgres;

--
-- TOC entry 5062 (class 0 OID 0)
-- Dependencies: 423
-- Name: riipartizione_territoriale_to_rip_terr_id_rel_rip_ter_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.riipartizione_territoriale_to_rip_terr_id_rel_rip_ter_pk_seq OWNED BY public.riipartizione_territoriale_to_rip_terr.id_rel_rip_ter_pk;


--
-- TOC entry 434 (class 1259 OID 82815)
-- Name: rimini_dopo_1000_gisid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rimini_dopo_1000_gisid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 4000000
    CACHE 40;


ALTER TABLE public.rimini_dopo_1000_gisid_seq OWNER TO postgres;

--
-- TOC entry 388 (class 1259 OID 32994)
-- Name: rimini_dopo_1000; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rimini_dopo_1000 (
    gisid integer DEFAULT nextval('public.rimini_dopo_1000_gisid_seq'::regclass) NOT NULL,
    gid integer,
    idtonini character varying(80),
    nome character varying(80),
    idsitocpa character varying(80),
    quartiere integer,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.rimini_dopo_1000 OWNER TO postgres;

--
-- TOC entry 448 (class 1259 OID 123876)
-- Name: sampling_points; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sampling_points (
    id integer NOT NULL,
    geom public.geometry(MultiPoint,3004),
    gid bigint,
    porta_gall numeric
);


ALTER TABLE public.sampling_points OWNER TO postgres;

--
-- TOC entry 447 (class 1259 OID 123874)
-- Name: sampling_points_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sampling_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sampling_points_id_seq OWNER TO postgres;

--
-- TOC entry 5063 (class 0 OID 0)
-- Dependencies: 447
-- Name: sampling_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sampling_points_id_seq OWNED BY public.sampling_points.id;


--
-- TOC entry 446 (class 1259 OID 123833)
-- Name: sampling_pointsc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sampling_pointsc (
    id integer NOT NULL,
    geom public.geometry(Point,3004),
    gid bigint,
    porta_gall numeric
);


ALTER TABLE public.sampling_pointsc OWNER TO postgres;

--
-- TOC entry 445 (class 1259 OID 123831)
-- Name: sampling_pointsc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sampling_pointsc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sampling_pointsc_id_seq OWNER TO postgres;

--
-- TOC entry 5064 (class 0 OID 0)
-- Dependencies: 445
-- Name: sampling_pointsc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sampling_pointsc_id_seq OWNED BY public.sampling_pointsc.id;


--
-- TOC entry 453 (class 1259 OID 181315)
-- Name: segnalazioni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.segnalazioni (
    id_segnalazione integer NOT NULL,
    nome_segnalatore text NOT NULL,
    tipo_segnalazione text NOT NULL,
    data_segnalazione text NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.segnalazioni OWNER TO postgres;

--
-- TOC entry 452 (class 1259 OID 181313)
-- Name: segnalazioni_id_segnalazione_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.segnalazioni_id_segnalazione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.segnalazioni_id_segnalazione_seq OWNER TO postgres;

--
-- TOC entry 5065 (class 0 OID 0)
-- Dependencies: 452
-- Name: segnalazioni_id_segnalazione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.segnalazioni_id_segnalazione_seq OWNED BY public.segnalazioni.id_segnalazione;


--
-- TOC entry 389 (class 1259 OID 33003)
-- Name: sezioni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sezioni (
    gid integer NOT NULL,
    descr character varying(80),
    "ID_Sezione" character varying(80),
    the_geom public.geometry,
    sito character varying,
    area integer DEFAULT 1,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'LINESTRING'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.sezioni OWNER TO postgres;

--
-- TOC entry 390 (class 1259 OID 33013)
-- Name: shape_finali_polygon; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shape_finali_polygon (
    gid integer,
    area_s integer,
    scavo_s character varying(255),
    us_s integer,
    stratigrap integer,
    tipo_us_s character varying(255),
    rilievo_or character varying(255),
    disegnator character varying(255),
    data character varying(255),
    the_geom public.geometry(Polygon,3004)
);


ALTER TABLE public.shape_finali_polygon OWNER TO postgres;

--
-- TOC entry 391 (class 1259 OID 33019)
-- Name: site_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.site_table (
    id_sito integer NOT NULL,
    sito text,
    nazione character varying(100),
    regione character varying(100),
    comune character varying(100),
    descrizione text,
    provincia character varying DEFAULT 'inserici un valore'::character varying,
    definizione_sito character varying DEFAULT 'inserici un valore'::character varying,
    find_check integer DEFAULT 0
);


ALTER TABLE public.site_table OWNER TO postgres;

--
-- TOC entry 392 (class 1259 OID 33028)
-- Name: site_table_id_sito_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.site_table_id_sito_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.site_table_id_sito_seq OWNER TO postgres;

--
-- TOC entry 5066 (class 0 OID 0)
-- Dependencies: 392
-- Name: site_table_id_sito_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.site_table_id_sito_seq OWNED BY public.site_table.id_sito;


--
-- TOC entry 393 (class 1259 OID 33030)
-- Name: siti; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.siti (
    gid integer NOT NULL,
    "OBJECTID" integer,
    "ID_SITO" character varying(254),
    "Shape_Leng" double precision,
    "Shape_Area" double precision,
    the_geom public.geometry(MultiPolygon),
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.siti OWNER TO postgres;

--
-- TOC entry 436 (class 1259 OID 91012)
-- Name: siti_arch_preventiva; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.siti_arch_preventiva (
    gid integer NOT NULL,
    geom public.geometry(MultiPoint,3004),
    progetto character varying(150),
    id_sito integer,
    definizion character varying(250),
    nome character varying(250),
    regione character varying(250),
    provincia character varying(250),
    comune character varying(250),
    localita character varying(250),
    indirizzo character varying(250),
    cron_inizi bigint,
    cron_fin bigint,
    data_lett character varying(50),
    fonti_bib text,
    descr_ap text,
    stato_cons character varying(254),
    interventi text,
    qtamin_slm double precision,
    qtamax_slm double precision,
    qta_m_dpco double precision,
    ip_sp_st_m double precision,
    osserv_qta text,
    tipo_rinv character varying(254),
    fonti_arch text
);


ALTER TABLE public.siti_arch_preventiva OWNER TO postgres;

--
-- TOC entry 435 (class 1259 OID 91010)
-- Name: siti_arch_preventiva_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.siti_arch_preventiva_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.siti_arch_preventiva_gid_seq OWNER TO postgres;

--
-- TOC entry 5067 (class 0 OID 0)
-- Dependencies: 435
-- Name: siti_arch_preventiva_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.siti_arch_preventiva_gid_seq OWNED BY public.siti_arch_preventiva.gid;


--
-- TOC entry 394 (class 1259 OID 33038)
-- Name: siti_con_nome; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.siti_con_nome (
    gid integer NOT NULL,
    "ID_SITO" character varying(254),
    "DENOMINAZI" character varying(59),
    "CHECK" integer,
    the_geom public.geometry(MultiPolygon),
    test smallint,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.siti_con_nome OWNER TO postgres;

--
-- TOC entry 395 (class 1259 OID 33046)
-- Name: siti_con_nome_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.siti_con_nome_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.siti_con_nome_gid_seq OWNER TO postgres;

--
-- TOC entry 5068 (class 0 OID 0)
-- Dependencies: 395
-- Name: siti_con_nome_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.siti_con_nome_gid_seq OWNED BY public.siti_con_nome.gid;


--
-- TOC entry 396 (class 1259 OID 33048)
-- Name: siti_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.siti_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.siti_gid_seq OWNER TO postgres;

--
-- TOC entry 5069 (class 0 OID 0)
-- Dependencies: 396
-- Name: siti_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.siti_gid_seq OWNED BY public.siti.gid;


--
-- TOC entry 397 (class 1259 OID 33050)
-- Name: siti_spea2; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.siti_spea2 (
    gid integer NOT NULL,
    "DENOMINAZI" character varying(80),
    "CATEGORIA" character varying(80),
    "EPOCA" character varying(80),
    "DESCRIZION" character varying(80),
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.siti_spea2 OWNER TO postgres;

--
-- TOC entry 431 (class 1259 OID 82793)
-- Name: soprannomi_covignano; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soprannomi_covignano (
    id_soprannomi integer NOT NULL,
    soprannome text NOT NULL,
    soprannome_variante text NOT NULL,
    ghetto text NOT NULL,
    famiglia text NOT NULL,
    rif_secondo_cognome text NOT NULL,
    personaggio_rif text NOT NULL,
    rif_luogo text NOT NULL,
    geom public.geometry(Point,3004)
);


ALTER TABLE public.soprannomi_covignano OWNER TO postgres;

--
-- TOC entry 433 (class 1259 OID 82805)
-- Name: soprannomi_covignano_bis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soprannomi_covignano_bis (
    id_soprannomi_pk integer NOT NULL,
    id_maioli integer,
    soprannome text NOT NULL,
    soprannome_variante text,
    nome text,
    cognome text,
    rif_secondo_cognome text,
    personaggio_rif text,
    ghetto text,
    famiglia text,
    rif_luogo text,
    mestiere text,
    geom public.geometry(Point,3004),
    "check" character(2)
);


ALTER TABLE public.soprannomi_covignano_bis OWNER TO postgres;

--
-- TOC entry 432 (class 1259 OID 82803)
-- Name: soprannomi_covignano_bis_id_soprannomi_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.soprannomi_covignano_bis_id_soprannomi_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.soprannomi_covignano_bis_id_soprannomi_pk_seq OWNER TO postgres;

--
-- TOC entry 5070 (class 0 OID 0)
-- Dependencies: 432
-- Name: soprannomi_covignano_bis_id_soprannomi_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.soprannomi_covignano_bis_id_soprannomi_pk_seq OWNED BY public.soprannomi_covignano_bis.id_soprannomi_pk;


--
-- TOC entry 430 (class 1259 OID 82791)
-- Name: soprannomi_covignano_id_soprannomi_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.soprannomi_covignano_id_soprannomi_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.soprannomi_covignano_id_soprannomi_seq OWNER TO postgres;

--
-- TOC entry 5071 (class 0 OID 0)
-- Dependencies: 430
-- Name: soprannomi_covignano_id_soprannomi_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.soprannomi_covignano_id_soprannomi_seq OWNED BY public.soprannomi_covignano.id_soprannomi;


--
-- TOC entry 398 (class 1259 OID 33059)
-- Name: spessore_stratigrafico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.spessore_stratigrafico (
    ogc_fid integer NOT NULL,
    wkb_geometry public.geometry,
    cat integer,
    value double precision,
    CONSTRAINT enforce_dims_wkb_geometry CHECK ((public.st_ndims(wkb_geometry) = 2)),
    CONSTRAINT enforce_geotype_wkb_geometry CHECK (((public.geometrytype(wkb_geometry) = 'POLYGON'::text) OR (wkb_geometry IS NULL))),
    CONSTRAINT enforce_srid_wkb_geometry CHECK ((public.st_srid(wkb_geometry) = 3004))
);


ALTER TABLE public.spessore_stratigrafico OWNER TO postgres;

--
-- TOC entry 399 (class 1259 OID 33068)
-- Name: spessore_stratigrafico_ogc_fid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.spessore_stratigrafico_ogc_fid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.spessore_stratigrafico_ogc_fid_seq OWNER TO postgres;

--
-- TOC entry 5072 (class 0 OID 0)
-- Dependencies: 399
-- Name: spessore_stratigrafico_ogc_fid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.spessore_stratigrafico_ogc_fid_seq OWNED BY public.spessore_stratigrafico.ogc_fid;


--
-- TOC entry 401 (class 1259 OID 33076)
-- Name: struttura_table_id_struttura_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.struttura_table_id_struttura_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.struttura_table_id_struttura_seq OWNER TO postgres;

--
-- TOC entry 5073 (class 0 OID 0)
-- Dependencies: 401
-- Name: struttura_table_id_struttura_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.struttura_table_id_struttura_seq OWNED BY public.struttura_table.id_struttura;


--
-- TOC entry 402 (class 1259 OID 33078)
-- Name: strutturale_con_trincee_per_gvc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.strutturale_con_trincee_per_gvc (
    gid integer NOT NULL,
    the_geom public.geometry(LineString,3004),
    layer character varying(254),
    subclasses character varying(254),
    extendeden character varying(254),
    linetype character varying(254),
    entityhand character varying(254),
    text character varying(254)
);


ALTER TABLE public.strutturale_con_trincee_per_gvc OWNER TO postgres;

--
-- TOC entry 403 (class 1259 OID 33084)
-- Name: strutturale_con_trincee_per_gvc_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.strutturale_con_trincee_per_gvc_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.strutturale_con_trincee_per_gvc_gid_seq OWNER TO postgres;

--
-- TOC entry 5074 (class 0 OID 0)
-- Dependencies: 403
-- Name: strutturale_con_trincee_per_gvc_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.strutturale_con_trincee_per_gvc_gid_seq OWNED BY public.strutturale_con_trincee_per_gvc.gid;


--
-- TOC entry 426 (class 1259 OID 66379)
-- Name: strutture_ricettive; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.strutture_ricettive (
    id_str_ricett_pk integer NOT NULL,
    nome text NOT NULL,
    indirizzo text,
    periodo_apertura_iniz date,
    periodo_apertura_fin date,
    orari_estivi text,
    orari_invernali text NOT NULL,
    link text NOT NULL,
    geom public.geometry(Point,3004),
    tipo_struttura text
);


ALTER TABLE public.strutture_ricettive OWNER TO postgres;

--
-- TOC entry 425 (class 1259 OID 66377)
-- Name: strutture_ricettive_id_str_ricett_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.strutture_ricettive_id_str_ricett_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.strutture_ricettive_id_str_ricett_pk_seq OWNER TO postgres;

--
-- TOC entry 5075 (class 0 OID 0)
-- Dependencies: 425
-- Name: strutture_ricettive_id_str_ricett_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.strutture_ricettive_id_str_ricett_pk_seq OWNED BY public.strutture_ricettive.id_str_ricett_pk;


--
-- TOC entry 404 (class 1259 OID 33086)
-- Name: supercinema_quote; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.supercinema_quote (
    gid integer NOT NULL,
    id integer,
    fshape text,
    entity text,
    layer text,
    color integer,
    elevation double precision,
    thickness double precision,
    text text,
    heighttext double precision,
    rotationtext double precision,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 3004))
);


ALTER TABLE public.supercinema_quote OWNER TO postgres;

--
-- TOC entry 405 (class 1259 OID 33094)
-- Name: supercinema_quote_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.supercinema_quote_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supercinema_quote_gid_seq OWNER TO postgres;

--
-- TOC entry 5076 (class 0 OID 0)
-- Dependencies: 405
-- Name: supercinema_quote_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.supercinema_quote_gid_seq OWNED BY public.supercinema_quote.gid;


--
-- TOC entry 406 (class 1259 OID 33096)
-- Name: tafonomia_table_id_tafonomia_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tafonomia_table_id_tafonomia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tafonomia_table_id_tafonomia_seq OWNER TO postgres;

--
-- TOC entry 5077 (class 0 OID 0)
-- Dependencies: 406
-- Name: tafonomia_table_id_tafonomia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tafonomia_table_id_tafonomia_seq OWNED BY public.tafonomia_table.id_tafonomia;


--
-- TOC entry 407 (class 1259 OID 33098)
-- Name: test_copi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_copi (
    gid integer NOT NULL,
    id integer,
    prova character varying(80),
    the_geom public.geometry(Polygon,3004)
);


ALTER TABLE public.test_copi OWNER TO postgres;

--
-- TOC entry 408 (class 1259 OID 33104)
-- Name: test_copi_gid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_copi_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.test_copi_gid_seq OWNER TO postgres;

--
-- TOC entry 5078 (class 0 OID 0)
-- Dependencies: 408
-- Name: test_copi_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_copi_gid_seq OWNED BY public.test_copi.gid;


--
-- TOC entry 409 (class 1259 OID 33106)
-- Name: us_strati_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.us_strati_view AS
 SELECT us_table.id_us,
    us_table.sito,
    us_table.area,
    us_table.us,
    us_table.struttura,
    pyunitastratigrafiche.scavo_s,
    pyunitastratigrafiche.area_s,
    pyunitastratigrafiche.us_s,
    pyunitastratigrafiche.gid,
    pyunitastratigrafiche.the_geom
   FROM (public.us_table
     JOIN public.pyunitastratigrafiche ON (((((pyunitastratigrafiche.scavo_s)::text = us_table.sito) AND ((pyunitastratigrafiche.area_s)::text = (us_table.area)::text)) AND (pyunitastratigrafiche.us_s = us_table.us))));


ALTER TABLE public.us_strati_view OWNER TO postgres;

--
-- TOC entry 410 (class 1259 OID 33111)
-- Name: us_table_corsini; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.us_table_corsini (
    id_us integer NOT NULL,
    sito character varying,
    area character varying(4),
    us integer,
    d_stratigrafica character varying(100),
    d_interpretativa character varying(100),
    descrizione character varying,
    interpretazione character varying,
    periodo_iniziale character varying(4),
    fase_iniziale character varying(4),
    periodo_finale character varying(4),
    fase_finale character varying(4),
    scavato character varying(2),
    attivita character varying(4),
    anno_scavo character varying(4),
    metodo_di_scavo character varying(20),
    inclusi character varying,
    campioni character varying,
    rapporti character varying,
    data_schedatura character varying(20),
    schedatore character varying(25),
    formazione character varying(20),
    stato_di_conservazione character varying(20),
    colore character varying(20),
    consistenza character varying(20),
    struttura character varying(30),
    cont_per character varying(200),
    order_layer integer,
    documentazione character varying
);


ALTER TABLE public.us_table_corsini OWNER TO postgres;

--
-- TOC entry 411 (class 1259 OID 33117)
-- Name: us_table_id_us_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.us_table_id_us_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.us_table_id_us_seq OWNER TO postgres;

--
-- TOC entry 5079 (class 0 OID 0)
-- Dependencies: 411
-- Name: us_table_id_us_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.us_table_id_us_seq OWNED BY public.us_table.id_us;


--
-- TOC entry 412 (class 1259 OID 33119)
-- Name: us_table_toimp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.us_table_toimp (
    id_us integer NOT NULL,
    sito text,
    area character varying(4),
    us integer,
    d_stratigrafica character varying(100),
    d_interpretativa character varying(100),
    descrizione text,
    interpretazione text,
    periodo_iniziale character varying(4),
    fase_iniziale character varying(4),
    periodo_finale character varying(4),
    fase_finale character varying(4),
    scavato character varying(100),
    attivita character varying(4),
    anno_scavo character varying(4),
    metodo_di_scavo character varying(20),
    inclusi text,
    campioni text,
    rapporti text,
    data_schedatura character varying(20),
    schedatore character varying(25),
    formazione character varying(20),
    stato_di_conservazione character varying(20),
    colore character varying(20),
    consistenza character varying(20),
    struttura character varying(30),
    cont_per character varying,
    order_layer integer,
    documentazione text
);


ALTER TABLE public.us_table_toimp OWNER TO postgres;

--
-- TOC entry 413 (class 1259 OID 33125)
-- Name: us_table_toimp_id_us_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.us_table_toimp_id_us_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.us_table_toimp_id_us_seq OWNER TO postgres;

--
-- TOC entry 5080 (class 0 OID 0)
-- Dependencies: 413
-- Name: us_table_toimp_id_us_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.us_table_toimp_id_us_seq OWNED BY public.us_table_toimp.id_us;


--
-- TOC entry 414 (class 1259 OID 33127)
-- Name: ut_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ut_table (
    id_ut integer NOT NULL,
    progetto character varying(100),
    nr_ut integer,
    ut_letterale character varying(100),
    def_ut character varying(100),
    descrizione_ut text,
    interpretazione_ut character varying(100),
    nazione character varying(100),
    regione character varying(100),
    provincia character varying(100),
    comune character varying(100),
    frazione character varying(100),
    localita character varying(100),
    indirizzo character varying(100),
    nr_civico character varying(100),
    carta_topo_igm character varying(100),
    carta_ctr character varying(100),
    coord_geografiche character varying(100),
    coord_piane character varying(100),
    quota real,
    andamento_terreno_pendenza character varying(100),
    utilizzo_suolo_vegetazione character varying(100),
    descrizione_empirica_suolo text,
    descrizione_luogo text,
    metodo_rilievo_e_ricognizione character varying(100),
    geometria character varying(100),
    bibliografia text,
    data character varying(100),
    ora_meteo character varying(100),
    responsabile character varying(100),
    dimensioni_ut character varying(100),
    rep_per_mq character varying(100),
    rep_datanti character varying(100),
    "periodo_I" character varying(100),
    "datazione_I" character varying(100),
    "interpretazione_I" character varying(100),
    "periodo_II" character varying(100),
    "datazione_II" character varying(100),
    "interpretazione_II" character varying(100),
    documentazione text,
    enti_tutela_vincoli character varying(100),
    indagini_preliminari character varying(100)
);


ALTER TABLE public.ut_table OWNER TO postgres;

--
-- TOC entry 415 (class 1259 OID 33133)
-- Name: ut_table_id_ut_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ut_table_id_ut_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ut_table_id_ut_seq OWNER TO postgres;

--
-- TOC entry 5081 (class 0 OID 0)
-- Dependencies: 415
-- Name: ut_table_id_ut_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ut_table_id_ut_seq OWNED BY public.ut_table.id_ut;


--
-- TOC entry 4409 (class 2604 OID 33135)
-- Name: Ctr_Pesaro_5000 gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ctr_Pesaro_5000" ALTER COLUMN gid SET DEFAULT nextval('public."Ctr_Pesaro_5000_gid_seq"'::regclass);


--
-- TOC entry 4410 (class 2604 OID 33136)
-- Name: archeozoology_table id_archzoo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.archeozoology_table ALTER COLUMN id_archzoo SET DEFAULT nextval('public.archeozoology_table_id_archzoo_seq'::regclass);


--
-- TOC entry 4603 (class 2604 OID 107438)
-- Name: bf_battle id_battle_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bf_battle ALTER COLUMN id_battle_pk SET DEFAULT nextval('public.bf_battle_id_battle_pk_seq'::regclass);


--
-- TOC entry 4601 (class 2604 OID 107414)
-- Name: bf_camp id_camp_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bf_camp ALTER COLUMN id_camp_pk SET DEFAULT nextval('public.bf_camp_id_camp_pk_seq'::regclass);


--
-- TOC entry 4602 (class 2604 OID 107426)
-- Name: bf_displacement id_displacement_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bf_displacement ALTER COLUMN id_displacement_pk SET DEFAULT nextval('public.bf_displacement_id_displacement_pk_seq'::regclass);


--
-- TOC entry 4411 (class 2604 OID 33137)
-- Name: campioni_table id_campione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campioni_table ALTER COLUMN id_campione SET DEFAULT nextval('public.campioni_table_id_campione_seq'::regclass);


--
-- TOC entry 4412 (class 2604 OID 33138)
-- Name: canonica gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.canonica ALTER COLUMN gid SET DEFAULT nextval('public.canonica_gid_seq'::regclass);


--
-- TOC entry 4415 (class 2604 OID 33139)
-- Name: carta_archeologica_mansuelli gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carta_archeologica_mansuelli ALTER COLUMN gid SET DEFAULT nextval('public.carta_archeologica_mansuelli_gid_seq'::regclass);


--
-- TOC entry 4421 (class 2604 OID 33140)
-- Name: casto_calindri_particelle_pre_convegno gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casto_calindri_particelle_pre_convegno ALTER COLUMN gid SET DEFAULT nextval('public.casto_calindri_particelle_pre_convegno_gid_seq'::regclass);


--
-- TOC entry 4425 (class 2604 OID 33141)
-- Name: catastale_regione_marche_R11_11 gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."catastale_regione_marche_R11_11" ALTER COLUMN gid SET DEFAULT nextval('public."catastale_regione_marche_R11_11_gid_seq"'::regclass);


--
-- TOC entry 4426 (class 2604 OID 33142)
-- Name: catasto_calindri_comuni gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_comuni ALTER COLUMN gid SET DEFAULT nextval('public.catasto_calindri_comuni_gid_seq'::regclass);


--
-- TOC entry 4430 (class 2604 OID 33143)
-- Name: catasto_calindri_particelle gid2; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_particelle ALTER COLUMN gid2 SET DEFAULT nextval('public.catasto_calindri_particelle_gid2_seq'::regclass);


--
-- TOC entry 4431 (class 2604 OID 33144)
-- Name: catasto_calindri_per_comuni gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_per_comuni ALTER COLUMN gid SET DEFAULT nextval('public.catasto_calindri_per_comuni_gid_seq'::regclass);


--
-- TOC entry 4435 (class 2604 OID 33145)
-- Name: catasto_calindri_per_localita gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_per_localita ALTER COLUMN gid SET DEFAULT nextval('public.catasto_calindri_per_localita_gid_seq'::regclass);


--
-- TOC entry 4438 (class 2604 OID 33146)
-- Name: catasto_calindri_toponimo gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_toponimo ALTER COLUMN gid SET DEFAULT nextval('public.catasto_calindri_toponimo_gid_seq'::regclass);


--
-- TOC entry 4442 (class 2604 OID 33147)
-- Name: catasto_fano_2000_22 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_fano_2000_22 ALTER COLUMN id SET DEFAULT nextval('public.catasto_fano_2000_22_id_seq'::regclass);


--
-- TOC entry 4443 (class 2604 OID 33148)
-- Name: catasto_test gid2; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_test ALTER COLUMN gid2 SET DEFAULT nextval('public.catasto_test_gid2_seq'::regclass);


--
-- TOC entry 4447 (class 2604 OID 33149)
-- Name: conversione_geo_cpa id_conversione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversione_geo_cpa ALTER COLUMN id_conversione SET DEFAULT nextval('public.conversione_geo_cpa_id_conversione_seq'::regclass);


--
-- TOC entry 4597 (class 2604 OID 82766)
-- Name: covignano_open_park_siti id_cop; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.covignano_open_park_siti ALTER COLUMN id_cop SET DEFAULT nextval('public.covignano_open_park_siti_id_cop_seq'::regclass);


--
-- TOC entry 4448 (class 2604 OID 33150)
-- Name: ctr_provincia_pesaro_urbino_epsg3004 gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ctr_provincia_pesaro_urbino_epsg3004 ALTER COLUMN gid SET DEFAULT nextval('public.ctr_provincia_pesaro_urbino_epsg3004_gid_seq'::regclass);


--
-- TOC entry 4607 (class 2604 OID 164934)
-- Name: dati_ambientali id_dati_amb; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dati_ambientali ALTER COLUMN id_dati_amb SET DEFAULT nextval('public.dati_ambientali_id_dati_amb_seq'::regclass);


--
-- TOC entry 4449 (class 2604 OID 33151)
-- Name: deteta_table id_det_eta; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deteta_table ALTER COLUMN id_det_eta SET DEFAULT nextval('public.deteta_table_id_det_eta_seq'::regclass);


--
-- TOC entry 4450 (class 2604 OID 33152)
-- Name: detsesso_table id_det_sesso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detsesso_table ALTER COLUMN id_det_sesso SET DEFAULT nextval('public.detsesso_table_id_det_sesso_seq'::regclass);


--
-- TOC entry 4451 (class 2604 OID 33153)
-- Name: diacronia_siti_cpa iddiacronia; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diacronia_siti_cpa ALTER COLUMN iddiacronia SET DEFAULT nextval('public.diacronia_siti_cpa_id_diacronia_seq'::regclass);


--
-- TOC entry 4452 (class 2604 OID 33154)
-- Name: documentazione_table id_documentazione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentazione_table ALTER COLUMN id_documentazione SET DEFAULT nextval('public.documentazione_table_id_documentazione_seq'::regclass);


--
-- TOC entry 4456 (class 2604 OID 33155)
-- Name: fano_2000_unione gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fano_2000_unione ALTER COLUMN gid SET DEFAULT nextval('public.fano_2000_unione_gid_seq'::regclass);


--
-- TOC entry 4457 (class 2604 OID 33156)
-- Name: fano_500_centro_storico gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fano_500_centro_storico ALTER COLUMN gid SET DEFAULT nextval('public.fano_500_centro_storico_gid_seq'::regclass);


--
-- TOC entry 4604 (class 2604 OID 115663)
-- Name: griglia id_griglia_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.griglia ALTER COLUMN id_griglia_pk SET DEFAULT nextval('public.griglia_id_griglia_pk_seq'::regclass);


--
-- TOC entry 4458 (class 2604 OID 33157)
-- Name: individui_table id_scheda_ind; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.individui_table ALTER COLUMN id_scheda_ind SET DEFAULT nextval('public.individui_table_id_scheda_ind_seq'::regclass);


--
-- TOC entry 4593 (class 2604 OID 57660)
-- Name: inventario_lapidei_table id_invlap; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_lapidei_table ALTER COLUMN id_invlap SET DEFAULT nextval('public.inventario_lapidei_table_id_invlap_seq'::regclass);


--
-- TOC entry 4467 (class 2604 OID 33158)
-- Name: inventario_materiali_table id_invmat; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_materiali_table ALTER COLUMN id_invmat SET DEFAULT nextval('public.inventario_materiali_table_id_invmat_seq'::regclass);


--
-- TOC entry 4468 (class 2604 OID 33159)
-- Name: inventario_materiali_table_toimp id_invmat; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_materiali_table_toimp ALTER COLUMN id_invmat SET DEFAULT nextval('public.inventario_materiali_table_toimp_id_invmat_seq'::regclass);


--
-- TOC entry 4469 (class 2604 OID 33160)
-- Name: ipogeo_table id_ipogeo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ipogeo_table ALTER COLUMN id_ipogeo SET DEFAULT nextval('public.ipogeo_table_id_ipogeo_seq'::regclass);


--
-- TOC entry 4471 (class 2604 OID 33161)
-- Name: layer_styles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.layer_styles ALTER COLUMN id SET DEFAULT nextval('public.layer_styles_id_seq'::regclass);


--
-- TOC entry 4472 (class 2604 OID 33162)
-- Name: media_table id_media; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_table ALTER COLUMN id_media SET DEFAULT nextval('public.media_table_id_media_seq'::regclass);


--
-- TOC entry 4473 (class 2604 OID 33163)
-- Name: media_thumb_table id_media_thumb; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_thumb_table ALTER COLUMN id_media_thumb SET DEFAULT nextval('public.media_thumb_table_id_media_thumb_seq'::regclass);


--
-- TOC entry 4474 (class 2604 OID 33164)
-- Name: media_to_entity_table id_mediaToEntity; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_to_entity_table ALTER COLUMN "id_mediaToEntity" SET DEFAULT nextval('public."media_to_entity_table_id_mediaToEntity_seq"'::regclass);


--
-- TOC entry 4475 (class 2604 OID 33165)
-- Name: media_to_us_table id_mediaToUs; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_to_us_table ALTER COLUMN "id_mediaToUs" SET DEFAULT nextval('public."media_to_us_table_id_mediaToUs_seq"'::regclass);


--
-- TOC entry 4476 (class 2604 OID 33166)
-- Name: pdf_administrator_table id_pdf_administrator; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdf_administrator_table ALTER COLUMN id_pdf_administrator SET DEFAULT nextval('public.pdf_administrator_table_id_pdf_administrator_seq'::regclass);


--
-- TOC entry 4477 (class 2604 OID 33167)
-- Name: periodizzazione_table id_perfas; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.periodizzazione_table ALTER COLUMN id_perfas SET DEFAULT nextval('public.periodizzazione_table_id_perfas_seq'::regclass);


--
-- TOC entry 4478 (class 2604 OID 33168)
-- Name: pesaro_centrostorico_ctr_5000 gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pesaro_centrostorico_ctr_5000 ALTER COLUMN gid SET DEFAULT nextval('public.pesaro_centrostorico_ctr_5000_gid_seq'::regclass);


--
-- TOC entry 4480 (class 2604 OID 33169)
-- Name: pyarchinit_individui gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_individui ALTER COLUMN gid SET DEFAULT nextval('public.pyarchinit_individui_gid_seq'::regclass);


--
-- TOC entry 4543 (class 2604 OID 33170)
-- Name: pyarchinit_ripartizioni_temporali id_periodo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_ripartizioni_temporali ALTER COLUMN id_periodo SET DEFAULT nextval('public.pyarchinit_ripartizioni_temporali_id_periodo_seq'::regclass);


--
-- TOC entry 4544 (class 2604 OID 33171)
-- Name: pyarchinit_rou_thesaurus ID_rou; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_rou_thesaurus ALTER COLUMN "ID_rou" SET DEFAULT nextval('public."pyarchinit_rou_thesaurus_ID_rou_seq"'::regclass);


--
-- TOC entry 4551 (class 2604 OID 33172)
-- Name: pyarchinit_tafonomia gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_tafonomia ALTER COLUMN gid SET DEFAULT nextval('public.pyarchinit_tafonomia_gid_seq'::regclass);


--
-- TOC entry 4554 (class 2604 OID 33173)
-- Name: pyarchinit_thesaurus_sigle id_thesaurus_sigle; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_thesaurus_sigle ALTER COLUMN id_thesaurus_sigle SET DEFAULT nextval('public.pyarchinit_thesaurus_sigle_id_thesaurus_sigle_seq'::regclass);


--
-- TOC entry 4556 (class 2604 OID 33174)
-- Name: pyarchinit_us_negative_doc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_us_negative_doc ALTER COLUMN id SET DEFAULT nextval('public.pyarchinit_us_negative_doc_id_seq'::regclass);


--
-- TOC entry 4488 (class 2604 OID 33175)
-- Name: pyuscarlinee gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyuscarlinee ALTER COLUMN gid SET DEFAULT nextval('public.pyuscarlinee_gid_seq'::regclass);


--
-- TOC entry 4592 (class 2604 OID 41276)
-- Name: relashionship_check_table id_rel_check; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relashionship_check_table ALTER COLUMN id_rel_check SET DEFAULT nextval('public.relashionship_check_table_id_rel_check_seq'::regclass);


--
-- TOC entry 4594 (class 2604 OID 66362)
-- Name: riipartizione_territoriale id_div_terr_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.riipartizione_territoriale ALTER COLUMN id_div_terr_pk SET DEFAULT nextval('public.riipartizione_territoriale_id_div_terr_pk_seq'::regclass);


--
-- TOC entry 4595 (class 2604 OID 66374)
-- Name: riipartizione_territoriale_to_rip_terr id_rel_rip_ter_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.riipartizione_territoriale_to_rip_terr ALTER COLUMN id_rel_rip_ter_pk SET DEFAULT nextval('public.riipartizione_territoriale_to_rip_terr_id_rel_rip_ter_pk_seq'::regclass);


--
-- TOC entry 4606 (class 2604 OID 123879)
-- Name: sampling_points id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sampling_points ALTER COLUMN id SET DEFAULT nextval('public.sampling_points_id_seq'::regclass);


--
-- TOC entry 4605 (class 2604 OID 123836)
-- Name: sampling_pointsc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sampling_pointsc ALTER COLUMN id SET DEFAULT nextval('public.sampling_pointsc_id_seq'::regclass);


--
-- TOC entry 4608 (class 2604 OID 181318)
-- Name: segnalazioni id_segnalazione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segnalazioni ALTER COLUMN id_segnalazione SET DEFAULT nextval('public.segnalazioni_id_segnalazione_seq'::regclass);


--
-- TOC entry 4570 (class 2604 OID 33176)
-- Name: site_table id_sito; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.site_table ALTER COLUMN id_sito SET DEFAULT nextval('public.site_table_id_sito_seq'::regclass);


--
-- TOC entry 4571 (class 2604 OID 33177)
-- Name: siti gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti ALTER COLUMN gid SET DEFAULT nextval('public.siti_gid_seq'::regclass);


--
-- TOC entry 4600 (class 2604 OID 91015)
-- Name: siti_arch_preventiva gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti_arch_preventiva ALTER COLUMN gid SET DEFAULT nextval('public.siti_arch_preventiva_gid_seq'::regclass);


--
-- TOC entry 4574 (class 2604 OID 33178)
-- Name: siti_con_nome gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti_con_nome ALTER COLUMN gid SET DEFAULT nextval('public.siti_con_nome_gid_seq'::regclass);


--
-- TOC entry 4598 (class 2604 OID 82796)
-- Name: soprannomi_covignano id_soprannomi; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soprannomi_covignano ALTER COLUMN id_soprannomi SET DEFAULT nextval('public.soprannomi_covignano_id_soprannomi_seq'::regclass);


--
-- TOC entry 4599 (class 2604 OID 82808)
-- Name: soprannomi_covignano_bis id_soprannomi_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soprannomi_covignano_bis ALTER COLUMN id_soprannomi_pk SET DEFAULT nextval('public.soprannomi_covignano_bis_id_soprannomi_pk_seq'::regclass);


--
-- TOC entry 4580 (class 2604 OID 33179)
-- Name: spessore_stratigrafico ogc_fid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spessore_stratigrafico ALTER COLUMN ogc_fid SET DEFAULT nextval('public.spessore_stratigrafico_ogc_fid_seq'::regclass);


--
-- TOC entry 4584 (class 2604 OID 33180)
-- Name: struttura_table id_struttura; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.struttura_table ALTER COLUMN id_struttura SET DEFAULT nextval('public.struttura_table_id_struttura_seq'::regclass);


--
-- TOC entry 4585 (class 2604 OID 33181)
-- Name: strutturale_con_trincee_per_gvc gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.strutturale_con_trincee_per_gvc ALTER COLUMN gid SET DEFAULT nextval('public.strutturale_con_trincee_per_gvc_gid_seq'::regclass);


--
-- TOC entry 4596 (class 2604 OID 66382)
-- Name: strutture_ricettive id_str_ricett_pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.strutture_ricettive ALTER COLUMN id_str_ricett_pk SET DEFAULT nextval('public.strutture_ricettive_id_str_ricett_pk_seq'::regclass);


--
-- TOC entry 4586 (class 2604 OID 33182)
-- Name: supercinema_quote gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.supercinema_quote ALTER COLUMN gid SET DEFAULT nextval('public.supercinema_quote_gid_seq'::regclass);


--
-- TOC entry 4553 (class 2604 OID 33183)
-- Name: tafonomia_table id_tafonomia; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tafonomia_table ALTER COLUMN id_tafonomia SET DEFAULT nextval('public.tafonomia_table_id_tafonomia_seq'::regclass);


--
-- TOC entry 4589 (class 2604 OID 33184)
-- Name: test_copi gid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_copi ALTER COLUMN gid SET DEFAULT nextval('public.test_copi_gid_seq'::regclass);


--
-- TOC entry 4494 (class 2604 OID 33185)
-- Name: us_table id_us; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table ALTER COLUMN id_us SET DEFAULT nextval('public.us_table_id_us_seq'::regclass);


--
-- TOC entry 4590 (class 2604 OID 33186)
-- Name: us_table_toimp id_us; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table_toimp ALTER COLUMN id_us SET DEFAULT nextval('public.us_table_toimp_id_us_seq'::regclass);


--
-- TOC entry 4591 (class 2604 OID 33187)
-- Name: ut_table id_ut; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ut_table ALTER COLUMN id_ut SET DEFAULT nextval('public.ut_table_id_ut_seq'::regclass);


--
-- TOC entry 4612 (class 2606 OID 41010)
-- Name: Ctr_Pesaro_5000 Ctr_Pesaro_5000_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ctr_Pesaro_5000"
    ADD CONSTRAINT "Ctr_Pesaro_5000_pkey" PRIMARY KEY (gid);


--
-- TOC entry 4665 (class 2606 OID 41012)
-- Name: fabbricati_gbe Fabbricati_GBE_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fabbricati_gbe
    ADD CONSTRAINT "Fabbricati_GBE_pkey" PRIMARY KEY (gid);


--
-- TOC entry 4614 (class 2606 OID 41014)
-- Name: archeozoology_table ID_archzoo_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.archeozoology_table
    ADD CONSTRAINT "ID_archzoo_unico" UNIQUE (sito, quadrato);


--
-- TOC entry 4651 (class 2606 OID 41016)
-- Name: deteta_table ID_det_eta_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deteta_table
    ADD CONSTRAINT "ID_det_eta_unico" UNIQUE (sito, nr_individuo);


--
-- TOC entry 4655 (class 2606 OID 41018)
-- Name: detsesso_table ID_det_sesso_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detsesso_table
    ADD CONSTRAINT "ID_det_sesso_unico" UNIQUE (sito, num_individuo);


--
-- TOC entry 4673 (class 2606 OID 41020)
-- Name: individui_table ID_individuo_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.individui_table
    ADD CONSTRAINT "ID_individuo_unico" UNIQUE (sito, nr_individuo);


--
-- TOC entry 4618 (class 2606 OID 41022)
-- Name: campioni_table ID_invcamp_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campioni_table
    ADD CONSTRAINT "ID_invcamp_unico" UNIQUE (sito, nr_campione);


--
-- TOC entry 4661 (class 2606 OID 41024)
-- Name: documentazione_table ID_invdoc_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentazione_table
    ADD CONSTRAINT "ID_invdoc_unico" UNIQUE (sito, tipo_documentazione, nome_doc);


--
-- TOC entry 4820 (class 2606 OID 57667)
-- Name: inventario_lapidei_table ID_invlap_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_lapidei_table
    ADD CONSTRAINT "ID_invlap_unico" UNIQUE (sito, scheda_numero);


--
-- TOC entry 4677 (class 2606 OID 41026)
-- Name: inventario_materiali_table ID_invmat_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_materiali_table
    ADD CONSTRAINT "ID_invmat_unico" UNIQUE (sito, numero_inventario);


--
-- TOC entry 4681 (class 2606 OID 41028)
-- Name: inventario_materiali_table_toimp ID_invmat_unico_toimp; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_materiali_table_toimp
    ADD CONSTRAINT "ID_invmat_unico_toimp" UNIQUE (sito, numero_inventario);


--
-- TOC entry 4685 (class 2606 OID 41030)
-- Name: ipogeo_table ID_ipogeo_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ipogeo_table
    ADD CONSTRAINT "ID_ipogeo_unico" UNIQUE (sito_ipogeo, numero_ipogeo);


--
-- TOC entry 4699 (class 2606 OID 41032)
-- Name: media_to_entity_table ID_mediaToEntity_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_to_entity_table
    ADD CONSTRAINT "ID_mediaToEntity_unico" UNIQUE (id_entity, entity_type, id_media);


--
-- TOC entry 4703 (class 2606 OID 41034)
-- Name: media_to_us_table ID_mediaToUs_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_to_us_table
    ADD CONSTRAINT "ID_mediaToUs_unico" UNIQUE (id_media, id_us);


--
-- TOC entry 4695 (class 2606 OID 41036)
-- Name: media_thumb_table ID_media_thumb_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_thumb_table
    ADD CONSTRAINT "ID_media_thumb_unico" UNIQUE (media_thumb_filename);


--
-- TOC entry 4691 (class 2606 OID 41038)
-- Name: media_table ID_media_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_table
    ADD CONSTRAINT "ID_media_unico" UNIQUE (filepath);


--
-- TOC entry 4707 (class 2606 OID 41040)
-- Name: pdf_administrator_table ID_pdf_administrator_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdf_administrator_table
    ADD CONSTRAINT "ID_pdf_administrator_unico" UNIQUE (table_name, modello);


--
-- TOC entry 4711 (class 2606 OID 41042)
-- Name: periodizzazione_table ID_perfas_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.periodizzazione_table
    ADD CONSTRAINT "ID_perfas_unico" UNIQUE (sito, periodo, fase);


--
-- TOC entry 4749 (class 2606 OID 41044)
-- Name: pyarchinit_rou_thesaurus ID_rou_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_rou_thesaurus
    ADD CONSTRAINT "ID_rou_pk" PRIMARY KEY ("ID_rou");


--
-- TOC entry 4784 (class 2606 OID 41046)
-- Name: site_table ID_sito_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.site_table
    ADD CONSTRAINT "ID_sito_unico" UNIQUE (sito);


--
-- TOC entry 4797 (class 2606 OID 41048)
-- Name: struttura_table ID_struttura_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.struttura_table
    ADD CONSTRAINT "ID_struttura_unico" UNIQUE (sito, sigla_struttura, numero_struttura);


--
-- TOC entry 4763 (class 2606 OID 41050)
-- Name: tafonomia_table ID_tafonomia_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tafonomia_table
    ADD CONSTRAINT "ID_tafonomia_unico" UNIQUE (sito, nr_scheda_taf);


--
-- TOC entry 4718 (class 2606 OID 41052)
-- Name: pyarchinit_codici_tipologia ID_tipologia_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_codici_tipologia
    ADD CONSTRAINT "ID_tipologia_unico" UNIQUE (tipologia_progetto, tipologia_gruppo, tipologia_codice, tipologia_sottocodice);


--
-- TOC entry 4735 (class 2606 OID 41054)
-- Name: us_table ID_us_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table
    ADD CONSTRAINT "ID_us_unico" UNIQUE (sito, area, us);


--
-- TOC entry 4810 (class 2606 OID 41056)
-- Name: us_table_toimp ID_us_unico_toimp; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table_toimp
    ADD CONSTRAINT "ID_us_unico_toimp" UNIQUE (sito, area, us);


--
-- TOC entry 4814 (class 2606 OID 41058)
-- Name: ut_table ID_ut_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ut_table
    ADD CONSTRAINT "ID_ut_unico" UNIQUE (progetto, nr_ut, ut_letterale);


--
-- TOC entry 4616 (class 2606 OID 41060)
-- Name: archeozoology_table archeozoology_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.archeozoology_table
    ADD CONSTRAINT archeozoology_table_pkey PRIMARY KEY (id_archzoo);


--
-- TOC entry 4853 (class 2606 OID 107443)
-- Name: bf_battle bf_battle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bf_battle
    ADD CONSTRAINT bf_battle_pkey PRIMARY KEY (id_battle_pk);


--
-- TOC entry 4847 (class 2606 OID 107419)
-- Name: bf_camp bf_camp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bf_camp
    ADD CONSTRAINT bf_camp_pkey PRIMARY KEY (id_camp_pk);


--
-- TOC entry 4850 (class 2606 OID 107431)
-- Name: bf_displacement bf_displacement_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bf_displacement
    ADD CONSTRAINT bf_displacement_pkey PRIMARY KEY (id_displacement_pk);


--
-- TOC entry 4870 (class 2606 OID 230513)
-- Name: biblio biblio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biblio
    ADD CONSTRAINT biblio_pkey PRIMARY KEY (id_biblio_pk);


--
-- TOC entry 4620 (class 2606 OID 41062)
-- Name: campioni_table campioni_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campioni_table
    ADD CONSTRAINT campioni_table_pkey PRIMARY KEY (id_campione);


--
-- TOC entry 4622 (class 2606 OID 41064)
-- Name: canonica canonica_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.canonica
    ADD CONSTRAINT canonica_pkey PRIMARY KEY (gid);


--
-- TOC entry 4624 (class 2606 OID 41066)
-- Name: carta_archeologica_mansuelli carta_archeologica_mansuelli_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carta_archeologica_mansuelli
    ADD CONSTRAINT carta_archeologica_mansuelli_pkey PRIMARY KEY (gid);


--
-- TOC entry 4626 (class 2606 OID 41068)
-- Name: casto_calindri_particelle_pre_convegno casto_calindri_particelle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casto_calindri_particelle_pre_convegno
    ADD CONSTRAINT casto_calindri_particelle_pkey PRIMARY KEY (gid);


--
-- TOC entry 4628 (class 2606 OID 41070)
-- Name: catastale_regione_marche_R11_11 catastale_regione_marche_R11_11_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."catastale_regione_marche_R11_11"
    ADD CONSTRAINT "catastale_regione_marche_R11_11_pkey" PRIMARY KEY (gid);


--
-- TOC entry 4631 (class 2606 OID 41072)
-- Name: catasto_calindri_comuni catasto_calindri_comuni_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_comuni
    ADD CONSTRAINT catasto_calindri_comuni_pkey PRIMARY KEY (gid);


--
-- TOC entry 4633 (class 2606 OID 41074)
-- Name: catasto_calindri_particelle catasto_calindri_particelle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_particelle
    ADD CONSTRAINT catasto_calindri_particelle_pkey PRIMARY KEY (gid2);


--
-- TOC entry 4635 (class 2606 OID 41076)
-- Name: catasto_calindri_per_comuni catasto_calindri_per_comuni_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_per_comuni
    ADD CONSTRAINT catasto_calindri_per_comuni_pkey PRIMARY KEY (gid);


--
-- TOC entry 4637 (class 2606 OID 41078)
-- Name: catasto_calindri_per_localita catasto_calindri_per_localita_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_per_localita
    ADD CONSTRAINT catasto_calindri_per_localita_pkey PRIMARY KEY (gid);


--
-- TOC entry 4639 (class 2606 OID 41080)
-- Name: catasto_calindri_toponimo catasto_calindri_toponimo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_calindri_toponimo
    ADD CONSTRAINT catasto_calindri_toponimo_pkey PRIMARY KEY (gid);


--
-- TOC entry 4642 (class 2606 OID 41082)
-- Name: catasto_fano_2000_22 catasto_fano_2000_22_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_fano_2000_22
    ADD CONSTRAINT catasto_fano_2000_22_pkey PRIMARY KEY (id);


--
-- TOC entry 4644 (class 2606 OID 41084)
-- Name: catasto_test catasto_test_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catasto_test
    ADD CONSTRAINT catasto_test_pkey PRIMARY KEY (gid2);


--
-- TOC entry 4832 (class 2606 OID 82771)
-- Name: covignano_open_park_siti covignano_open_park_siti_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.covignano_open_park_siti
    ADD CONSTRAINT covignano_open_park_siti_pkey PRIMARY KEY (id_cop);


--
-- TOC entry 4648 (class 2606 OID 41086)
-- Name: ctr_provincia_pesaro_urbino_epsg3004 ctr_provincia_pesaro_urbino_epsg3004_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ctr_provincia_pesaro_urbino_epsg3004
    ADD CONSTRAINT ctr_provincia_pesaro_urbino_epsg3004_pkey PRIMARY KEY (gid);


--
-- TOC entry 4862 (class 2606 OID 164939)
-- Name: dati_ambientali dati_ambientali_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dati_ambientali
    ADD CONSTRAINT dati_ambientali_pkey PRIMARY KEY (id_dati_amb);


--
-- TOC entry 4653 (class 2606 OID 41088)
-- Name: deteta_table deteta_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deteta_table
    ADD CONSTRAINT deteta_table_pkey PRIMARY KEY (id_det_eta);


--
-- TOC entry 4657 (class 2606 OID 41090)
-- Name: detsesso_table detsesso_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detsesso_table
    ADD CONSTRAINT detsesso_table_pkey PRIMARY KEY (id_det_sesso);


--
-- TOC entry 4663 (class 2606 OID 41092)
-- Name: documentazione_table documentazione_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentazione_table
    ADD CONSTRAINT documentazione_table_pkey PRIMARY KEY (id_documentazione);


--
-- TOC entry 4667 (class 2606 OID 41094)
-- Name: fano_2000_unione fano_2000_unione_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fano_2000_unione
    ADD CONSTRAINT fano_2000_unione_pkey PRIMARY KEY (gid);


--
-- TOC entry 4670 (class 2606 OID 41098)
-- Name: fano_500_centro_storico fano_500_centro_storico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fano_500_centro_storico
    ADD CONSTRAINT fano_500_centro_storico_pkey PRIMARY KEY (gid);


--
-- TOC entry 4856 (class 2606 OID 115668)
-- Name: griglia griglia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.griglia
    ADD CONSTRAINT griglia_pkey PRIMARY KEY (id_griglia_pk);


--
-- TOC entry 4726 (class 2606 OID 41100)
-- Name: pyarchinit_ipogei grotte_shape_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_ipogei
    ADD CONSTRAINT grotte_shape_pkey PRIMARY KEY (gid);


--
-- TOC entry 4646 (class 2606 OID 41102)
-- Name: conversione_geo_cpa id_conversione_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversione_geo_cpa
    ADD CONSTRAINT id_conversione_pk PRIMARY KEY (id_conversione);


--
-- TOC entry 4659 (class 2606 OID 41104)
-- Name: diacronia_siti_cpa id_diacronia_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diacronia_siti_cpa
    ADD CONSTRAINT id_diacronia_pk PRIMARY KEY (iddiacronia);


--
-- TOC entry 4724 (class 2606 OID 41106)
-- Name: pyarchinit_inventario_materiali id_im_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_inventario_materiali
    ADD CONSTRAINT id_im_pk PRIMARY KEY (idim_pk);


--
-- TOC entry 4745 (class 2606 OID 41108)
-- Name: pyarchinit_ripartizioni_temporali id_periodo_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_ripartizioni_temporali
    ADD CONSTRAINT id_periodo_pk PRIMARY KEY (id_periodo);


--
-- TOC entry 4767 (class 2606 OID 41110)
-- Name: pyarchinit_thesaurus_sigle id_thesaurus_sigle_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_thesaurus_sigle
    ADD CONSTRAINT id_thesaurus_sigle_pk PRIMARY KEY (id_thesaurus_sigle);


--
-- TOC entry 4720 (class 2606 OID 41112)
-- Name: pyarchinit_codici_tipologia id_tip_tombe_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_codici_tipologia
    ADD CONSTRAINT id_tip_tombe_pk PRIMARY KEY (id);


--
-- TOC entry 4675 (class 2606 OID 41114)
-- Name: individui_table individui_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.individui_table
    ADD CONSTRAINT individui_table_pkey PRIMARY KEY (id_scheda_ind);


--
-- TOC entry 4822 (class 2606 OID 57665)
-- Name: inventario_lapidei_table inventario_lapidei_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_lapidei_table
    ADD CONSTRAINT inventario_lapidei_table_pkey PRIMARY KEY (id_invlap);


--
-- TOC entry 4679 (class 2606 OID 41116)
-- Name: inventario_materiali_table inventario_materiali_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_materiali_table
    ADD CONSTRAINT inventario_materiali_table_pkey PRIMARY KEY (id_invmat);


--
-- TOC entry 4683 (class 2606 OID 41118)
-- Name: inventario_materiali_table_toimp inventario_materiali_table_toimp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario_materiali_table_toimp
    ADD CONSTRAINT inventario_materiali_table_toimp_pkey PRIMARY KEY (id_invmat);


--
-- TOC entry 4687 (class 2606 OID 41120)
-- Name: ipogeo_table ipogeo_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ipogeo_table
    ADD CONSTRAINT ipogeo_table_pkey PRIMARY KEY (id_ipogeo);


--
-- TOC entry 4689 (class 2606 OID 41122)
-- Name: layer_styles layer_styles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.layer_styles
    ADD CONSTRAINT layer_styles_pkey PRIMARY KEY (id);


--
-- TOC entry 4728 (class 2606 OID 41124)
-- Name: pyarchinit_linee_rif linee_riferimento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_linee_rif
    ADD CONSTRAINT linee_riferimento_pkey PRIMARY KEY (gid);


--
-- TOC entry 4693 (class 2606 OID 41126)
-- Name: media_table media_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_table
    ADD CONSTRAINT media_table_pkey PRIMARY KEY (id_media);


--
-- TOC entry 4697 (class 2606 OID 41128)
-- Name: media_thumb_table media_thumb_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_thumb_table
    ADD CONSTRAINT media_thumb_table_pkey PRIMARY KEY (id_media_thumb);


--
-- TOC entry 4701 (class 2606 OID 41130)
-- Name: media_to_entity_table media_to_entity_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_to_entity_table
    ADD CONSTRAINT media_to_entity_table_pkey PRIMARY KEY ("id_mediaToEntity");


--
-- TOC entry 4705 (class 2606 OID 41132)
-- Name: media_to_us_table media_to_us_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.media_to_us_table
    ADD CONSTRAINT media_to_us_table_pkey PRIMARY KEY ("id_mediaToUs");


--
-- TOC entry 4867 (class 2606 OID 181330)
-- Name: nove_rocche nove_rocche_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nove_rocche
    ADD CONSTRAINT nove_rocche_pkey PRIMARY KEY (gid);


--
-- TOC entry 4709 (class 2606 OID 41134)
-- Name: pdf_administrator_table pdf_administrator_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdf_administrator_table
    ADD CONSTRAINT pdf_administrator_table_pkey PRIMARY KEY (id_pdf_administrator);


--
-- TOC entry 4835 (class 2606 OID 82785)
-- Name: percorsi_visita percorsi_visita_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.percorsi_visita
    ADD CONSTRAINT percorsi_visita_pkey PRIMARY KEY (id);


--
-- TOC entry 4713 (class 2606 OID 41136)
-- Name: periodizzazione_table periodizzazione_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.periodizzazione_table
    ADD CONSTRAINT periodizzazione_table_pkey PRIMARY KEY (id_perfas);


--
-- TOC entry 4747 (class 2606 OID 41138)
-- Name: pyarchinit_ripartizioni_temporali periodo_fase_unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_ripartizioni_temporali
    ADD CONSTRAINT periodo_fase_unico UNIQUE (sito, sigla_periodo, sigla_fase);


--
-- TOC entry 4715 (class 2606 OID 41140)
-- Name: pesaro_centrostorico_ctr_5000 pesaro_centrostorico_ctr_5000_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pesaro_centrostorico_ctr_5000
    ADD CONSTRAINT pesaro_centrostorico_ctr_5000_pkey PRIMARY KEY (gid);


--
-- TOC entry 4722 (class 2606 OID 41142)
-- Name: pyarchinit_individui pyarchinit_individui_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_individui
    ADD CONSTRAINT pyarchinit_individui_pkey PRIMARY KEY (gid);


--
-- TOC entry 4740 (class 2606 OID 41144)
-- Name: pyarchinit_quote pyarchinit_quote_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_quote
    ADD CONSTRAINT pyarchinit_quote_pkey PRIMARY KEY (gid);


--
-- TOC entry 4742 (class 2606 OID 41146)
-- Name: pyarchinit_ripartizioni_spaziali pyarchinit_ripartizioni_spaziali_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_ripartizioni_spaziali
    ADD CONSTRAINT pyarchinit_ripartizioni_spaziali_pkey PRIMARY KEY (gid);


--
-- TOC entry 4751 (class 2606 OID 41148)
-- Name: pyarchinit_sezioni pyarchinit_sezioni_29092009_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_sezioni
    ADD CONSTRAINT pyarchinit_sezioni_29092009_pkey PRIMARY KEY (gid);


--
-- TOC entry 4753 (class 2606 OID 41150)
-- Name: pyarchinit_siti pyarchinit_siti_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_siti
    ADD CONSTRAINT pyarchinit_siti_pkey PRIMARY KEY (gid);


--
-- TOC entry 4756 (class 2606 OID 41152)
-- Name: pyarchinit_sondaggi pyarchinit_sondaggi_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_sondaggi
    ADD CONSTRAINT pyarchinit_sondaggi_pkey PRIMARY KEY (gid);


--
-- TOC entry 4758 (class 2606 OID 41154)
-- Name: pyarchinit_strutture_ipotesi pyarchinit_strutture_ipotesi_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_strutture_ipotesi
    ADD CONSTRAINT pyarchinit_strutture_ipotesi_pkey PRIMARY KEY (gid);


--
-- TOC entry 4760 (class 2606 OID 41156)
-- Name: pyarchinit_tafonomia pyarchinit_tafonomia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_tafonomia
    ADD CONSTRAINT pyarchinit_tafonomia_pkey PRIMARY KEY (gid);


--
-- TOC entry 4769 (class 2606 OID 41158)
-- Name: pyarchinit_tipologia_sepolture pyarchinit_tipologia_sepolture_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_tipologia_sepolture
    ADD CONSTRAINT pyarchinit_tipologia_sepolture_pkey PRIMARY KEY (gid);


--
-- TOC entry 4771 (class 2606 OID 41160)
-- Name: pyarchinit_us_negative_doc pyarchinit_us_negative_doc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_us_negative_doc
    ADD CONSTRAINT pyarchinit_us_negative_doc_pkey PRIMARY KEY (id);


--
-- TOC entry 4731 (class 2606 OID 41162)
-- Name: pyarchinit_punti_rif pyarchnit_punti_riferimento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyarchinit_punti_rif
    ADD CONSTRAINT pyarchnit_punti_riferimento_pkey PRIMARY KEY (gid);


--
-- TOC entry 4774 (class 2606 OID 41164)
-- Name: pyunitastratigrafiche pyunitastratigrafiche_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyunitastratigrafiche
    ADD CONSTRAINT pyunitastratigrafiche_pkey PRIMARY KEY (gid);


--
-- TOC entry 4777 (class 2606 OID 41166)
-- Name: pyuscaratterizzazioni pyuscaratterizzazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyuscaratterizzazioni
    ADD CONSTRAINT pyuscaratterizzazioni_pkey PRIMARY KEY (gid);

ALTER TABLE public.pyuscaratterizzazioni CLUSTER ON pyuscaratterizzazioni_pkey;


--
-- TOC entry 4733 (class 2606 OID 41168)
-- Name: pyuscarlinee pyuscarlinee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pyuscarlinee
    ADD CONSTRAINT pyuscarlinee_pkey PRIMARY KEY (gid);


--
-- TOC entry 4818 (class 2606 OID 41281)
-- Name: relashionship_check_table relashionship_check_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relashionship_check_table
    ADD CONSTRAINT relashionship_check_table_pkey PRIMARY KEY (id_rel_check);


--
-- TOC entry 4872 (class 2606 OID 230527)
-- Name: rif_biblio_siti rif_biblio_siti_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rif_biblio_siti
    ADD CONSTRAINT rif_biblio_siti_pkey PRIMARY KEY (id_rif_biblio_siti_pk);


--
-- TOC entry 4824 (class 2606 OID 66367)
-- Name: riipartizione_territoriale riipartizione_territoriale_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.riipartizione_territoriale
    ADD CONSTRAINT riipartizione_territoriale_pkey PRIMARY KEY (id_div_terr_pk);


--
-- TOC entry 4827 (class 2606 OID 66376)
-- Name: riipartizione_territoriale_to_rip_terr riipartizione_territoriale_to_rip_terr_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.riipartizione_territoriale_to_rip_terr
    ADD CONSTRAINT riipartizione_territoriale_to_rip_terr_pkey PRIMARY KEY (id_rel_rip_ter_pk);


--
-- TOC entry 4779 (class 2606 OID 41170)
-- Name: rimini_dopo_1000 rimini_dopo_1000_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rimini_dopo_1000
    ADD CONSTRAINT rimini_dopo_1000_pkey PRIMARY KEY (gisid);


--
-- TOC entry 4860 (class 2606 OID 123881)
-- Name: sampling_points sampling_points_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sampling_points
    ADD CONSTRAINT sampling_points_pkey PRIMARY KEY (id);


--
-- TOC entry 4858 (class 2606 OID 123838)
-- Name: sampling_pointsc sampling_pointsc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sampling_pointsc
    ADD CONSTRAINT sampling_pointsc_pkey PRIMARY KEY (id);


--
-- TOC entry 4865 (class 2606 OID 181323)
-- Name: segnalazioni segnalazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segnalazioni
    ADD CONSTRAINT segnalazioni_pkey PRIMARY KEY (id_segnalazione);


--
-- TOC entry 4781 (class 2606 OID 41172)
-- Name: sezioni sezioni_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sezioni
    ADD CONSTRAINT sezioni_pkey PRIMARY KEY (gid);


--
-- TOC entry 4786 (class 2606 OID 41174)
-- Name: site_table site_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.site_table
    ADD CONSTRAINT site_table_pkey PRIMARY KEY (id_sito);


--
-- TOC entry 4845 (class 2606 OID 91017)
-- Name: siti_arch_preventiva siti_arch_preventiva_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti_arch_preventiva
    ADD CONSTRAINT siti_arch_preventiva_pkey PRIMARY KEY (gid);


--
-- TOC entry 4790 (class 2606 OID 41176)
-- Name: siti_con_nome siti_con_nome_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti_con_nome
    ADD CONSTRAINT siti_con_nome_pkey PRIMARY KEY (gid);


--
-- TOC entry 4788 (class 2606 OID 41178)
-- Name: siti siti_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti
    ADD CONSTRAINT siti_pkey PRIMARY KEY (gid);


--
-- TOC entry 4792 (class 2606 OID 41180)
-- Name: siti_spea2 siti_spea2_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.siti_spea2
    ADD CONSTRAINT siti_spea2_pkey PRIMARY KEY (gid);


--
-- TOC entry 4842 (class 2606 OID 82813)
-- Name: soprannomi_covignano_bis soprannomi_covignano_bis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soprannomi_covignano_bis
    ADD CONSTRAINT soprannomi_covignano_bis_pkey PRIMARY KEY (id_soprannomi_pk);


--
-- TOC entry 4839 (class 2606 OID 82801)
-- Name: soprannomi_covignano soprannomi_covignano_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soprannomi_covignano
    ADD CONSTRAINT soprannomi_covignano_pkey PRIMARY KEY (id_soprannomi);


--
-- TOC entry 4795 (class 2606 OID 41182)
-- Name: spessore_stratigrafico spessore_stratigrafico_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spessore_stratigrafico
    ADD CONSTRAINT spessore_stratigrafico_pk PRIMARY KEY (ogc_fid);


--
-- TOC entry 4799 (class 2606 OID 41184)
-- Name: struttura_table struttura_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.struttura_table
    ADD CONSTRAINT struttura_table_pkey PRIMARY KEY (id_struttura);


--
-- TOC entry 4802 (class 2606 OID 41186)
-- Name: strutturale_con_trincee_per_gvc strutturale_con_trincee_per_gvc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.strutturale_con_trincee_per_gvc
    ADD CONSTRAINT strutturale_con_trincee_per_gvc_pkey PRIMARY KEY (gid);


--
-- TOC entry 4830 (class 2606 OID 66387)
-- Name: strutture_ricettive strutture_ricettive_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.strutture_ricettive
    ADD CONSTRAINT strutture_ricettive_pkey PRIMARY KEY (id_str_ricett_pk);


--
-- TOC entry 4804 (class 2606 OID 41188)
-- Name: supercinema_quote supercinema_quote_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.supercinema_quote
    ADD CONSTRAINT supercinema_quote_pkey PRIMARY KEY (gid);


--
-- TOC entry 4765 (class 2606 OID 41190)
-- Name: tafonomia_table tafonomia_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tafonomia_table
    ADD CONSTRAINT tafonomia_table_pkey PRIMARY KEY (id_tafonomia);


--
-- TOC entry 4806 (class 2606 OID 41192)
-- Name: test_copi test_copi_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_copi
    ADD CONSTRAINT test_copi_pkey PRIMARY KEY (gid);


--
-- TOC entry 4808 (class 2606 OID 41194)
-- Name: us_table_corsini us_table_corsini_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table_corsini
    ADD CONSTRAINT us_table_corsini_pkey PRIMARY KEY (id_us);


--
-- TOC entry 4738 (class 2606 OID 41196)
-- Name: us_table us_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table
    ADD CONSTRAINT us_table_pkey PRIMARY KEY (id_us);


--
-- TOC entry 4812 (class 2606 OID 41198)
-- Name: us_table_toimp us_table_toimp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.us_table_toimp
    ADD CONSTRAINT us_table_toimp_pkey PRIMARY KEY (id_us);


--
-- TOC entry 4816 (class 2606 OID 41200)
-- Name: ut_table ut_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ut_table
    ADD CONSTRAINT ut_table_pkey PRIMARY KEY (id_ut);


--
-- TOC entry 4736 (class 1259 OID 41203)
-- Name: order_layer_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_layer_index ON public.us_table USING btree (order_layer DESC);

ALTER TABLE public.us_table CLUSTER ON order_layer_index;


--
-- TOC entry 4854 (class 1259 OID 107444)
-- Name: sidx_bf_battle_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_bf_battle_geom ON public.bf_battle USING gist (geom);


--
-- TOC entry 4848 (class 1259 OID 107420)
-- Name: sidx_bf_camp_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_bf_camp_geom ON public.bf_camp USING gist (geom);


--
-- TOC entry 4851 (class 1259 OID 107432)
-- Name: sidx_bf_displacement_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_bf_displacement_geom ON public.bf_displacement USING gist (geom);


--
-- TOC entry 4629 (class 1259 OID 41204)
-- Name: sidx_catastale_regione_marche_R11_11_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "sidx_catastale_regione_marche_R11_11_the_geom" ON public."catastale_regione_marche_R11_11" USING gist (the_geom);


--
-- TOC entry 4640 (class 1259 OID 41205)
-- Name: sidx_catasto_calindri_toponimo_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_catasto_calindri_toponimo_the_geom ON public.catasto_calindri_toponimo USING gist (the_geom);


--
-- TOC entry 4833 (class 1259 OID 82772)
-- Name: sidx_covignano_open_park_siti_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_covignano_open_park_siti_geom ON public.covignano_open_park_siti USING gist (geom);


--
-- TOC entry 4649 (class 1259 OID 41206)
-- Name: sidx_ctr_provincia_pesaro_urbino_epsg3004_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_ctr_provincia_pesaro_urbino_epsg3004_the_geom ON public.ctr_provincia_pesaro_urbino_epsg3004 USING gist (the_geom);


--
-- TOC entry 4863 (class 1259 OID 164940)
-- Name: sidx_dati_ambientali_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_dati_ambientali_geom ON public.dati_ambientali USING gist (geom);


--
-- TOC entry 4668 (class 1259 OID 41207)
-- Name: sidx_fano_2000_unione_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_fano_2000_unione_the_geom ON public.fano_2000_unione USING gist (the_geom);


--
-- TOC entry 4671 (class 1259 OID 41208)
-- Name: sidx_fano_500_centro_storico_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_fano_500_centro_storico_the_geom ON public.fano_500_centro_storico USING gist (the_geom);


--
-- TOC entry 4868 (class 1259 OID 181334)
-- Name: sidx_nove_rocche_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_nove_rocche_the_geom ON public.nove_rocche USING gist (the_geom);


--
-- TOC entry 4836 (class 1259 OID 82790)
-- Name: sidx_percorsi_visita_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_percorsi_visita_geom ON public.percorsi_visita USING gist (geom);


--
-- TOC entry 4716 (class 1259 OID 41209)
-- Name: sidx_pesaro_centrostorico_ctr_5000_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pesaro_centrostorico_ctr_5000_the_geom ON public.pesaro_centrostorico_ctr_5000 USING gist (the_geom);


--
-- TOC entry 4729 (class 1259 OID 41210)
-- Name: sidx_pyarchinit_linee_rif_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pyarchinit_linee_rif_the_geom ON public.pyarchinit_linee_rif USING gist (the_geom);


--
-- TOC entry 4743 (class 1259 OID 41211)
-- Name: sidx_pyarchinit_ripartizioni_spaziali_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pyarchinit_ripartizioni_spaziali_the_geom ON public.pyarchinit_ripartizioni_spaziali USING gist (the_geom);


--
-- TOC entry 4754 (class 1259 OID 41212)
-- Name: sidx_pyarchinit_siti_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pyarchinit_siti_the_geom ON public.pyarchinit_siti USING gist (the_geom);


--
-- TOC entry 4761 (class 1259 OID 41213)
-- Name: sidx_pyarchinit_tafonomia_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pyarchinit_tafonomia_the_geom ON public.pyarchinit_tafonomia USING gist (the_geom);


--
-- TOC entry 4772 (class 1259 OID 41214)
-- Name: sidx_pyarchinit_us_negative_doc_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pyarchinit_us_negative_doc_geom ON public.pyarchinit_us_negative_doc USING gist (geom);


--
-- TOC entry 4775 (class 1259 OID 41215)
-- Name: sidx_pyunitastratigrafiche_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_pyunitastratigrafiche_the_geom ON public.pyunitastratigrafiche USING gist (the_geom);


--
-- TOC entry 4825 (class 1259 OID 66368)
-- Name: sidx_riipartizione_territoriale_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_riipartizione_territoriale_geom ON public.riipartizione_territoriale USING gist (geom);


--
-- TOC entry 4782 (class 1259 OID 41216)
-- Name: sidx_sezioni; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_sezioni ON public.sezioni USING gist (the_geom);


--
-- TOC entry 4843 (class 1259 OID 91021)
-- Name: sidx_siti_arch_preventiva_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_siti_arch_preventiva_geom ON public.siti_arch_preventiva USING gist (geom);


--
-- TOC entry 4840 (class 1259 OID 82814)
-- Name: sidx_soprannomi_covignano_bis_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_soprannomi_covignano_bis_geom ON public.soprannomi_covignano_bis USING gist (geom);


--
-- TOC entry 4837 (class 1259 OID 82802)
-- Name: sidx_soprannomi_covignano_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_soprannomi_covignano_geom ON public.soprannomi_covignano USING gist (geom);


--
-- TOC entry 4800 (class 1259 OID 41217)
-- Name: sidx_strutturale_con_trincee_per_gvc_the_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_strutturale_con_trincee_per_gvc_the_geom ON public.strutturale_con_trincee_per_gvc USING gist (the_geom);


--
-- TOC entry 4828 (class 1259 OID 66388)
-- Name: sidx_strutture_ricettive_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sidx_strutture_ricettive_geom ON public.strutture_ricettive USING gist (geom);


--
-- TOC entry 4793 (class 1259 OID 41218)
-- Name: spessore_stratigrafico_geom_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX spessore_stratigrafico_geom_idx ON public.spessore_stratigrafico USING gist (wkb_geometry);


--
-- TOC entry 5011 (class 0 OID 0)
-- Dependencies: 20
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2018-10-02 21:35:07

--
-- PostgreSQL database dump complete
--
