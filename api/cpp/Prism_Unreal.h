// This file uses Unreal Engine 5.0 coding standards https://docs.unrealengine.com/5.0/en-US/epic-cplusplus-coding-standard-for-unreal-engine/

#ifndef PRISM_UNREAL_API
#define PRISM_UNREAL_API

// #include <CoreMinimal.h>
#include <VectorTypes.h>

// We use excluding defines like to have everything in one file, which means that we can change the PRISM_VECX_CLASS_EXTRA macros
// depending on the modules which get included. TODO Figure out a simple alternative way to extend these macros which allows for
// the code for different Unreal modules to be in separate files
#ifndef PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE
#include <DynamicMesh/DynamicMesh3.h>
#include <DynamicMesh/DynamicMeshOverlay.h>
#include <DynamicMesh/DynamicMeshAttributeSet.h>
#include <Util/CompactMaps.h>
#endif // PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE

// The macros below must be defined before including "Prism.h". This compile time error enforces this
#ifdef PRISM_API
#error Prism_Unreal.h must be included before Prism.h because it defines macros used by the Prism.h
#endif

#define PRISM_VEC2_CLASS_EXTRA\
	Vec2(UE::Math::TVector2<T> p) : Vec2(p.X, p.Y) {}

#define PRISM_VEC3_CLASS_EXTRA\
	Vec3(UE::Math::TVector<T> p) : Vec3(p.X, p.Y, p.Z) {}

#define PRISM_VEC4_CLASS_EXTRA\
	Vec4(UE::Math::TVector4<T> p) : Vec4(p.X, p.Y, p.Z, p.W) {}

#define PRISM_COLOR_CLASS_EXTRA\
	Color(FColor c) : Color(c.R, c.G, c.B, c.A) {}

#define PRISM_OBJ_CLASS_EXTRA\
	void Write(const FString& filename) { return write(TCHAR_TO_UTF8(*filename)); } // not named `write` to prevent infinite recursion

#include "Prism.h"

namespace Prism
{

bool DocumentationForUnreal(bool bWriteFiles)
{
	using namespace Prism;
	Prism::Obj Obj;

	// Define some Unreal data types
	FVector   A(0,0,1),  B(1,0,1),  C(0,1,1);
	FVector3f D(0,0,2),  E(1,0,2),  F(0,1,2);
	FVector3d G(0,0,3),  H(1,0,3),  I(0,1,3);

	// This is the recommended way of passing Unreal vectors to the Prism::Obj API
	Obj.triangle3(V3(A), V3(B), V3(C)).newline();

	// You could also do the following but in this case you will need to specify the template parameter
	Obj.triangle3<float>(D, E, F).newline();

	// Note that if you use Obj::add or Obj::insert with Unreal vectors you must construct Prism's vector types
	// first. You might encounter this if you're doing some low-level stuff and forgot about Obj::vector3.
	Obj.v().insert(V3(G)).newline();
	Obj.v().insert(V3(H)).newline();
	Obj.v().insert(V3(I)).newline();
	Obj.triangle();

	// Uncomment this line to see the error message about missing operator<< you get if you omit this wrapping :(
	//Obj.v().insert(I).newline();

	// For functions using Prism::Color you can directly pass a FColor, you don't need to construct Prism's Color type,
	// so both of the following work:
	Obj.set_vertex_label_color(FColor::Red);
	Obj.set_triangle_label_color(Color(FColor::Blue)); // Works, but redundant and verbose

	Obj.set_vertex_index_labels_visible(true);
	Obj.set_triangle_index_labels_visible(true);

	if (bWriteFiles) {
		Obj.write("prism_DocumentationForUnreal.obj");
	}

	return true;
}

#ifndef PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE


struct FMakeDynamicMeshObjOptions
{
	// If true reverses the orientation of the faces
	bool bReverseOrientation = true;

	// If true will attempt to write the per-vertex normals and UVs to the OBJ instead of the per-element values
	bool bWritePerVertexValues = true;
};


Obj MakeDynamicMeshObj(const UE::Geometry::FDynamicMesh3& InMesh, FMakeDynamicMeshObjOptions Options = FMakeDynamicMeshObjOptions{})
{
	using namespace UE::Geometry;

	Obj Result;

	// We should compact the mesh to make sure the order that we write the vertex/normal/uv indices into obj is
	// consistent with the storage order
	FDynamicMesh3 Mesh;
	FCompactMaps CompactInfo;
	Mesh.CompactCopy(InMesh, true, true, true, true, &CompactInfo);

	// Compute an additional mapping from the compact mesh triangles to the input mesh triangles
	// i.e the inverse of the FCompactMaps
	TMap<int32, int32> CompactToInputTriangles; // Mesh -> InMesh
	CompactToInputTriangles.Reserve(Mesh.TriangleCount());
	for (int32 TriangleID : InMesh.TriangleIndicesItr())
	{
		const int32 CompactTriangleID = CompactInfo.GetTriangleMapping(TriangleID);
		if (CompactTriangleID != FCompactMaps::InvalidID)
		{
			CompactToInputTriangles.Add(CompactTriangleID, TriangleID);
		}
	}
	checkSlow(CompactToInputTriangles.Num() == Mesh.TriangleCount());

	TMap<int32, int32> CompactToInputVertices; // Mesh -> InMesh
	CompactToInputVertices.Reserve(Mesh.VertexCount());
	for (int32 VertexID : InMesh.VertexIndicesItr())
	{
		const int32 CompactVertexID = CompactInfo.GetVertexMapping(VertexID);
		if (CompactVertexID != FCompactMaps::InvalidID)
		{
			CompactToInputVertices.Add(CompactVertexID, VertexID);
		}
	}
	checkSlow(CompactToInputVertices.Num() == Mesh.VertexCount());

	if (Options.bReverseOrientation)
	{
		Mesh.ReverseOrientation();
	}

	bool bHasVertexNormals = Options.bWritePerVertexValues && Mesh.HasVertexNormals();
	bool bHasVertexUVs = Options.bWritePerVertexValues && Mesh.HasVertexUVs();

	for (int32 VID = 0;  VID < Mesh.VertexCount(); ++VID)
	{
		check(Mesh.IsVertex(VID)); // mesh is not compact

		// Note: Suffix indicates this is zero-based
		int32* InMeshVID0 = CompactToInputVertices.Find(VID);
		ensure(InMeshVID0 != nullptr);

		FVector3d Pos = Mesh.GetVertex(VID);
		Result.vertex3(V3(Pos)).annotation("VID").insert(*InMeshVID0).newline();

		if (bHasVertexNormals)
		{
			FVector3f Normal = Mesh.GetVertexNormal(VID);
			Result.normal3(V3f(Normal)).newline();
		}

		if (bHasVertexUVs)
		{
			FVector2f UV = Mesh.GetVertexUV(VID);
			Result.uv2(V2f(UV)).newline();
		}
	}

	const FDynamicMeshUVOverlay* UVs = nullptr;
	const FDynamicMeshNormalOverlay* Normals = nullptr;

	if (Options.bWritePerVertexValues == false && Mesh.Attributes())
	{
		UVs = Mesh.Attributes()->PrimaryUV();
		if (UVs)
		{
			for (int32 UI = 0; UI < UVs->ElementCount(); ++UI)
			{
				check(UVs->IsElement(UI))
				FVector2f UV = UVs->GetElement(UI);
				Result.uv2(V2f(UV)).newline();
			}
		}

		Normals = Mesh.Attributes()->PrimaryNormals();
		if (Normals)
		{
			for (int32 NI = 0; NI < Normals->ElementCount(); ++NI)
			{
				check(Normals->IsElement(NI));
				FVector3f Normal = Normals->GetElement(NI);
				Result.normal3(V3f(Normal)).newline();
			}
		}
	}

	for (int32 TID = 0; TID < Mesh.TriangleCount(); ++TID)
	{
		check(Mesh.IsTriangle(TID));

		// Note: Suffix indicates this is zero-based
		int32* InMeshTID0 = CompactToInputTriangles.Find(TID);
		ensure(InMeshTID0 != nullptr);

		FIndex3i TriVertices = Mesh.GetTriangle(TID);

		if (Options.bWritePerVertexValues)
		{
			if (bHasVertexNormals == false && bHasVertexUVs == false)
			{
				Result.triangle(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
			else if (bHasVertexNormals == true && bHasVertexUVs == false)
			{
				Result.triangle_vn(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
			else if (bHasVertexNormals == false && bHasVertexUVs == true)
			{
				Result.triangle_vt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
			else
			{
				Result.triangle_vnt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
		}
		else
		{
			bool bHaveUV = UVs && UVs->IsSetTriangle(TID);
			bool bHaveNormal = Normals && Normals->IsSetTriangle(TID);

			FIndex3i TriUVs = bHaveUV ? UVs->GetTriangle(TID) : FIndex3i::Invalid();
			FIndex3i TriNormals = bHaveNormal ? Normals->GetTriangle(TID) : FIndex3i::Invalid();

			if (bHaveUV && bHaveNormal)
			{
				Result.triangle_vnt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriNormals.A+1, TriNormals.B+1, TriNormals.C+1,
					TriUVs.A+1, TriUVs.B+1, TriUVs.C+1);
			}
			else if (bHaveUV)
			{
				Result.triangle_vt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriUVs.A+1, TriUVs.B+1, TriUVs.C+1);
			}
			else if (bHaveNormal)
			{
				Result.triangle_vnt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriNormals.A+1, TriNormals.B+1, TriNormals.C+1);
			}
			else
			{
				Result.triangle(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
		}
		Result.annotation("TID").insert(*InMeshTID0).newline();
	}

	// Set some useful item state in Prism via command annotations
 	// You could further configure the Prism item state at the call site before you call Obj::write()
	// Note the lines written by the following code are ignored by other obj viewers
	Result.set_annotations_visible(true);
	Result.set_edges_width(true);
	Result.set_edges_visible(true);

	return Result;
}

struct FMakeImageDimensionsObjOptions
{
	// If true adds point elements at the texel centers with an annotation showing the texel UV coordinates e.g., "UV(0.123 0.5)"
	bool bAnnotateTexelCentersWithUVCoordinates = true;

	// If true adds point elements at the texel centers with an annotation showing the texel index e.g., "Idx(3 7)"
	bool bAnnotateTexelCentersWithTexelIndex = true;

	// Digits of precision used when writing UV coordinates to annotations (See bAnnotateTexelCentersWithUVCoordinates)
	int UVAnnotationPrecision = 3;
};

// Returns a Prism::Obj which only uses negative element indices which means the result can be used with Prism::Obj::append
Obj MakeImageDimensionsObj(UE::Geometry::FImageDimensions Dims, FMakeImageDimensionsObjOptions Options = FMakeImageDimensionsObjOptions{})
{
	using namespace UE::Geometry;

	Obj Result;

	FVector2d TexelExtentUV = Dims.GetTexelSize();

	for (int LinearIndex = 0; LinearIndex < Dims.Num(); LinearIndex++)
	{
		FVector2i TexelIndex = Dims.GetCoords(LinearIndex);
		FVector2d TexelCenterUV = Dims.GetTexelUV(TexelIndex);
		Result.box2_center_extents(V2(TexelCenterUV), V2(TexelExtentUV)).newline();

		if (Options.bAnnotateTexelCentersWithUVCoordinates ||
			Options.bAnnotateTexelCentersWithTexelIndex)
		{
			Result.point2(V2(TexelCenterUV)); // No newline() here since we might add annotations
		}

		if (Options.bAnnotateTexelCentersWithTexelIndex)
		{
			Result.annotation("Idx(").add(V2(TexelIndex.X, TexelIndex.Y)).add(")"); // TODO Add a Prism::V2i type
		}

		if (Options.bAnnotateTexelCentersWithUVCoordinates)
		{
			Result.set_precision(Options.UVAnnotationPrecision);
			Result.annotation("UV(").add(V2(TexelCenterUV)).add(")");
			Result.set_precision_max_digits10<double>(); // Restore max precision for Image coordinates geometry
		}

		Result.newline();
	}

	// Set some useful item state in Prism via command annotations
 	// You could further configure the Prism item state at the call site before you call Obj::write()
	// Note the lines written by the following code are ignored by other obj viewers
	Result.set_annotations_visible(true);

	return Result;
}

#endif // PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE

} // namespace Prism

#endif // PRISM_UNREAL_API