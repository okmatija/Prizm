// This file uses Unreal Engine 5.0 coding standards https://docs.unrealengine.com/5.0/en-US/epic-cplusplus-coding-standard-for-unreal-engine/

#ifndef PRISM_UNREAL_CPP_API
#define PRISM_UNREAL_CPP_API

// #include <CoreMinimal.h>
#include <VectorTypes.h>

// The macros below must be defined before including "Prism.h". This compile time error enforces this
#ifdef PRISM_CPP_API
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

bool DocumentationForUnreal(bool WriteFiles)
{
	using namespace Prism;
	Prism::Obj Obj;

	// Define some Unreal data types
	FVector2d A(0,0),    B(1,0),    C(0,1);
	FVector3d D(0,0,1),  E(1,0,1),  F(0,1,1);
	FVector3f N0(1,0,0), N1(0,1,0), N2(0,0,1);

	// This is the recommended way of passing Unreal vectors to the Prism::Obj API
	Obj.triangle2(V2(A), V2(B), V2(C)).newline();

	// You could also do the following but in this case you will need to specify the template parameter
	Obj.triangle3<double>(D, E, F).newline();

	// // Note that if you use Obj::add or Obj::insert you must construct Prism's vector types
	// // nocommit
	// Obj.vn().insert(N0).newline();
	// Obj.vn().insert(N1).newline();
	// Obj.vn().insert(N2).newline();
	// Obj.triangle_vn();

	// For functions using Prism::Color you can directly pass a FColor, you don't need to construct Prism's Color type,
	// so both of the following work:
	Obj.set_vertex_label_color(FColor::Red); // preferred
	Obj.set_triangle_label_color(Color(FColor::Blue)); // works, but redundant and verbose

	Obj.set_vertex_index_labels_visible(true);
	Obj.set_triangle_index_labels_visible(true);

	if (WriteFiles) {
		Obj.write("prism_example_for_unreal.obj");
	}

	return true;
}

} // namespace Prism

#endif // PRISM_UNREAL_CPP_API