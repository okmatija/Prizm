from prizm import Obj, Vec2, Vec3, Color, documentation
import prizm
import unittest

def last_line(obj: str) -> str:
    return str(obj).splitlines()[-1]

class TestPrizm(unittest.TestCase):

    def test_documentation(self):
        self.assertTrue(documentation()) # If this fails debug with `python prizm.py --demo`

    def test_polyline(self):
        s = last_line(Obj().polyline(4))
        self.assertEqual(s, "l -4 -3 -2 -1")

        if True:
            obj = Obj()
            obj.set_use_negative_indices(False)

            # To test a realistic case with positive indices we need to add some vertices
            for i in range(0, 4):
                obj.vertex2(Vec2(i, -i))
            obj.polyline(4)

            s = last_line(obj)
            self.assertEqual(s, "l 1 2 3 4")

        s = last_line(Obj().polyline(4, True))
        self.assertEqual(s, "l -4 -3 -2 -1 -4")

        s = last_line(Obj().polyline_ids(1,2,3,4,5))
        self.assertEqual(s, "l 1 2 3 4 5")

        s = last_line(Obj().polyline_ids(*(1,2,3,4,5))) # This calls the same function as the case above
        self.assertEqual(s, "l 1 2 3 4 5")

        s = last_line(Obj().polyline_ids(1,2,3))
        self.assertEqual(s, "l 1 2 3")

        with self.assertRaises(TypeError):
            Obj().polyline_ids(1) # Expect at least two indices

        with self.assertRaises(TypeError): # Expect at least two indices
            Obj().polyline_ids(*(1))

        s = last_line(Obj().polyline_vn(4))
        self.assertEqual(s, "l -4//-4 -3//-3 -2//-2 -1//-1")

        s = last_line(Obj().polyline_vn(4, True))
        self.assertEqual(s, "l -4//-4 -3//-3 -2//-2 -1//-1 -4//-4")

        s = str(Obj().polyline2(Vec2(0,0), Vec2(1,1), Vec2(2,2)))
        self.assertEqual(s, "\nv 0 0\nv 1 1\nv 2 2\nl -3 -2 -1")

        s = str(Obj().polyline2(Vec2(0,0), Vec2(1,1), Vec2(2,2), closed=True)) # closed=False is the default
        self.assertEqual(s, "\nv 0 0\nv 1 1\nv 2 2\nl -3 -2 -1 -3")

        with self.assertRaises(TypeError): # Expect at least two points
            Obj().polyline2(Vec2(0,0))

    def test_polygon(self):
        pass # @Incomplete

if __name__ == '__main__':
    unittest.main()