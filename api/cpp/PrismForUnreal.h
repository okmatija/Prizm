// This file uses the Unreal coding standards

#ifndef PRISM_FOR_UNREAL_CPP_API
#define PRISM_FOR_UNREAL_APP_API

#include <VectorTypes.h>

#ifndef PRISM_FOR_UNREAL_EXCLUDE_GEOMETRYCORE
#include <DynamicMesh/DynamicMesh3.h>
#include <DynamicMesh/DynamicMeshOverlay.h>
#include <DynamicMesh/DynamicMeshAttributeSet.h>
#include <Util/CompactMaps.h>
#endif // PRISM_FOR_UNREAL_EXCLUDE_GEOMETRYCORE

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

// Include the basic API after defining the macros above
#include "prism.h"

namespace prism
{

#ifndef PRISM_FOR_UNREAL_EXCLUDE_GEOMETRYCORE

using namespace UE::Geometry;

struct FMakeDynamicMeshObjSettings
{
	// If true reverses the orientation of the faces
	bool bReverseOrientation = true;

	// If true will attempt to write the per-vertex normals and UVs to the OBJ instead of the per-element values
	bool bWritePerVertexValues = true;
};

Obj MakeDynamicMeshObj(const FDynamicMesh3& InMesh, FMakeDynamicMeshObjSettings Settings = FMakeDynamicMeshObjSettings{})
{
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
    
	if (Settings.bReverseOrientation)
	{
		Mesh.ReverseOrientation();
	}

	bool bHasVertexNormals = Settings.bWritePerVertexValues && Mesh.HasVertexNormals();
	bool bHasVertexUVs = Settings.bWritePerVertexValues && Mesh.HasVertexUVs();

	for (int32 VID = 0;  VID < Mesh.VertexCount(); ++VID)
	{    
		check(Mesh.IsVertex(VID)); // mesh is not compact
        
		// Note: Suffix indicates this is zero-based
		int32* InMeshVID0 = CompactToInputVertices.Find(VID);
		ensure(InMeshVID0 != nullptr);
        
		FVector3d Pos = Mesh.GetVertex(VID);
		Result.vertex3(V3(Pos));
		Result.annotation("VID").insert(*InMeshVID0).newline();

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

	if (Settings.bWritePerVertexValues == false && Mesh.Attributes()) 
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

		if (Settings.bWritePerVertexValues) 
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
			bool bHaveUV = UVs != nullptr && UVs->IsSetTriangle(TID);
			bool bHaveNormal = Normals != nullptr && Normals->IsSetTriangle(TID);

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

	// Set some useful item state in Prism
	Result.set_annotations_visible(true);
	Result.set_edges_width(true);
	Result.set_edges_visible(true);

	return Result;
}

#endif // PRISM_FOR_UNREAL_EXCLUDE_GEOMETRYCORE

bool DocumentationForUnreal(bool WriteFiles)
{
	using namespace prism;
	prism::Obj Obj;

	// This the recommended way of using Unreal types
	FVector3d A3(0,0,1), B3(1,0,1), C3(0,1,1);
	Obj.triangle3(V3(A3), V3(B3), V3(C3));

	// You could also pass them without constructing Prism's vector type but then you need to specify the template parameter
	FVector2d A2(0,0), B2(1,0), C2(0,1);
	Obj.triangle2<double>(A2, B2, C2);

	// Note that if you use the insert function you should construct Prism's vector types
	// nocommit
	// FVector3f N0(1,0,0), N1(0,1,0), N2(0,0,1);
	// obj.triangle3(V3(A3), V3(B3), V3(C3), V3());

	// Enable label visibility and test FColor apis
	Obj.set_vertex_index_labels_visible(true);
	Obj.set_triangle_index_labels_visible(true);
	Obj.set_vertex_label_color(FColor::Red);
	Obj.set_triangle_label_color(FColor::Blue);

	if (WriteFiles) {
		Obj.write("prism_example_for_unreal.obj");
	}

	return true;
}

} // namespace prism

#endif // PRISM_FOR_UNREAL_CPP_API