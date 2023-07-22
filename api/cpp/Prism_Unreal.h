// This file uses Unreal Engine 5.0 coding standards https://docs.unrealengine.com/5.0/en-US/epic-cplusplus-coding-standard-for-unreal-engine/

#ifndef PRISM_UNREAL_API
#define PRISM_UNREAL_API

#include <CoreMinimal.h> // FString

// We use excluding defines like to have everything in one file, which means that we can change the PRISM_VECX_CLASS_EXTRA macros
// depending on the modules which get included. TODO Figure out a simple alternative way to extend these macros which allows for
// the code for different Unreal modules to be in separate files
#ifndef PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE
#include <VectorTypes.h>
#include <BoxTypes.h>
#include <DynamicMesh/DynamicMesh3.h>
#include <DynamicMesh/DynamicMeshOverlay.h>
#include <DynamicMesh/DynamicMeshAttributeSet.h>
#include <Image/ImageDimensions.h>
#include <Util/CompactMaps.h>
#endif // PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE

// The macros below must be defined before including "Prism.h". This compile time error enforces this
#ifdef PRISM_API
#error Prism_Unreal.h must be included before Prism.h because it defines macros used by the Prism.h
#endif

// TODO Add a Vec3i? constructed from UE::Geometry::FIndex3i, in GeometryCore

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
	// This block shows how to work with Unreal vector types
	{
		using namespace Prism;
		Prism::Obj Obj;

		// Define some Unreal data types
		FVector   A(0,0,1),  B(1,0,1),  C(0,1,1);
		FVector3f D(0,0,2),  E(1,0,2),  F(0,1,2);
		FVector3d G(0,0,3),  H(1,0,3),  I(0,1,3);

		// This is the recommended way of passing Unreal vectors to the Prism::Obj API
		Obj.triangle3(V3(A), V3(B), V3(C)).newline();

		// You could also do the following but in this case you will need to specify the template parameter, this is
		// sometimes more convenient than wrapping everything in a V3
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
			Obj.write("prism_DocumentationForUnreal_Ex1.obj");
		}
	}

	// This is a handy way to write FStrings to files in Unreal
	{
		FString Data;
		Data += "Here";
		Data += "Comes";
		Data += "Some Data";
		if (bWriteFiles) {
			Prism::Obj().add(std::string(TCHAR_TO_UTF8(*Data))).write("E:/Debug/prism_DocumentationForUnreal_Ex2.txt");
		}
	}

#ifndef PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE
	// This block shows some of the provided functions for Geometry Core
	{
		// @Incomplete
	}
#endif // PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE

	return true;
}

#ifndef PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE

// Write overlay element ids and element values as annotations with the format "@ <ElementID> @ <ElementValue>"
// The triangles of the Overlay.ParentMesh are split into 4 smaller triangles
// This is appendable, so you can add it the dynamic mesh obj.  Maybe make the command annotations/config commands optional to make this more useful.
// nocommit This function needs to flip the normals, and maybe it should be implemented by appending to the other one?
template<typename RealType, int ElementSize>
Obj MakeDynamicMeshOverlayObj(const UE::Geometry::TDynamicMeshOverlay<RealType, ElementSize>& Overlay)
{
	using namespace UE::Geometry;

	Obj Result;

	if (Overlay.GetParentMesh() == nullptr)
	{
		return Result;
	}

	FAxisAlignedBox3d Bounds = Overlay.GetParentMesh()->GetBounds();
	double Scale = Bounds.DiagonalLength();

	for (int32 TID = 0; TID < Overlay.GetParentMesh()->TriangleCount(); ++TID)
	{
		if (Overlay.GetParentMesh()->IsTriangle(TID))
		{
			FIndex3i ElementIDs = Overlay.GetTriangle(TID);

			RealType DataA[ElementSize];
			Overlay.GetElement(ElementIDs.A, DataA);

			RealType DataB[ElementSize];
			Overlay.GetElement(ElementIDs.B, DataB);

			RealType DataC[ElementSize];
			Overlay.GetElement(ElementIDs.C, DataC);

			FVector3d Centroid = Overlay.GetParentMesh()->GetTriCentroid(TID);
			FIndex3i Verts = Overlay.GetParentMesh()->GetTriangle(TID);


			FVector3d A = Overlay.GetParentMesh()->GetVertex(Verts.A);
			FVector3d B = Overlay.GetParentMesh()->GetVertex(Verts.B);
			FVector3d C = Overlay.GetParentMesh()->GetVertex(Verts.C);
			/*
			FVector3d AB = UE::Geometry::Lerp(A, B, .5);
			FVector3d BC = UE::Geometry::Lerp(B, C, .5);
			FVector3d CA = UE::Geometry::Lerp(C, A, .5);
			*/

			Result.triangle3<double>(A, B, C).newline(); // No annotation here, just for viz and to stop visibility checks

			FVector3d Bias = Overlay.GetParentMesh()->GetTriNormal(TID) * 0.001 * Scale;
			
			// Result.polygon3(4, V3(A), V3(CA), V3(Centroid), V3(AB));
			Result.point3<double>(Overlay.GetParentMesh()->GetTriBaryPoint(TID, .9, .05, .05) + Bias);
			Result.attribute(ElementIDs.A);
			Result.attribute();
			for (int i = 0; i < ElementSize; i++)
			{
				int OldPrecision;
				Result.set_precision(4, &OldPrecision);
				Result.insert(DataA[i]);
				Result.set_precision(OldPrecision);
			}
			Result.newline();

			// Result.polygon3(4, V3(B), V3(AB), V3(Centroid), V3(BC));
			Result.point3<double>(Overlay.GetParentMesh()->GetTriBaryPoint(TID, .05, .9, .05) + Bias);
			Result.attribute(ElementIDs.B);
			Result.attribute();
			for (int i = 0; i < ElementSize; i++)
			{
				int OldPrecision;
				Result.set_precision(4, &OldPrecision);
				Result.insert(DataB[i]);
				Result.set_precision(OldPrecision);
			}
			Result.newline();

			// Result.polygon3(4, V3(C), V3(BC), V3(Centroid), V3(CA));
			Result.point3<double>(Overlay.GetParentMesh()->GetTriBaryPoint(TID, .05, .05, .9) + Bias);
			Result.attribute(ElementIDs.B);
			Result.attribute();
			for (int i = 0; i < ElementSize; i++)
			{
				int OldPrecision;
				Result.set_precision(4, &OldPrecision);
				Result.insert(DataC[i]);
				Result.set_precision(OldPrecision);
			}
			Result.newline();
		}
	}

	return Result;
}



struct FMakeDynamicMeshObjOptions
{
	// If true reverses the orientation of the faces
	bool bReverseOrientation = true;

	// If true will attempt to write the per-vertex normals and UVs to the OBJ instead of the per-element values
	bool bWritePerVertexValues = true;

	// If true write "VID X" annotations on the OBJ v-directives, where X is the Vid into the input mesh (before the CompactCopy)
	bool bWriteVidAnnotations = false;

	// If true write "TID X" annotations on the OBJ f-directives, where X is the Tid into the input mesh (before the CompactCopy)
	bool bWriteTidAnnotations = false;
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
	TMap<int32, int32> CompactToInputTriangles; // Mesh Tid -> InMesh Tid
	if (Options.bWriteTidAnnotations)
	{
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
	}

	TMap<int32, int32> CompactToInputVertices; // Mesh Vid -> InMesh Vid
	if (Options.bWriteVidAnnotations)
	{
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
	}

	if (Options.bReverseOrientation)
	{
		Mesh.ReverseOrientation();
	}

	bool bHasVertexNormals = Options.bWritePerVertexValues && Mesh.HasVertexNormals();
	bool bHasVertexUVs = Options.bWritePerVertexValues && Mesh.HasVertexUVs();

	for (int32 VID = 0;  VID < Mesh.VertexCount(); ++VID)
	{
		check(Mesh.IsVertex(VID)); // mesh is not compact

		FVector3d Pos = Mesh.GetVertex(VID);
		Result.vertex3(V3(Pos));
		if (Options.bWriteVidAnnotations)
		{
			// Note: Suffix indicates this is zero-based
			int32* InMeshVID0 = CompactToInputVertices.Find(VID);
			ensure(InMeshVID0 != nullptr);
			Result.annotation("VID").insert(*InMeshVID0);
		}
		Result.newline();

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
		if (Options.bWriteTidAnnotations)
		{
			// Note: Suffix indicates this is zero-based
			int32* InMeshTID0 = CompactToInputTriangles.Find(TID);
			ensure(InMeshTID0 != nullptr);
			Result.annotation("TID").insert(*InMeshTID0);
		}
		Result.newline();
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
			Result.set_precision(); // Restore default precision
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